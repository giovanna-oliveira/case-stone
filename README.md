# Pipeline de Atribuição de CRM & Data Quality (BigQuery / MySQL 8.0)

Este repositório contém a solução completa para o pipeline de saneamento, ingestão, modelagem de dados e atribuição de conversões de CRM. A arquitetura foi construída utilizando a arquitetura Medallion (**Bronze**, **Silver** e **Gold**) no MySQL Workbench, garantindo qualidade de dados, rastreabilidade e idempotência no processamento.

## Arquitetura da Solução e Schemas

A solução está dividida em três camadas distintas para garantir a separação de responsabilidades e governança dos dados:

```
                  ┌──────────────────────────────┐
                  │    raw_sfmc_email_logs.csv   │
                  └──────────────┬───────────────┘
                                 │
                       (json_quality_gate.py)
                                 │
                   ┌─────────────┴─────────────┐
                   ▼                           ▼
      sfmc_email_logs_valid.csv    sfmc_email_logs_rejected.csv
                   │                           │
                   └─────────────┬─────────────┘
                                 │
                                 ▼
    ┌────────────────────────────────────────────────────────┐
    │  BRONZE_CLIENT_DATA (Staging Data / Raw Storage)        │
    │  - raw_crm_user_base                                   │
    │  - raw_sfmc_email_logs                             │
    │  - raw_whatsapp_provider                           │
    └────────────────────────────┬───────────────────────────┘
                                 │
                         (Upsert & Cleaning)
                                 │
                                 ▼
    ┌────────────────────────────────────────────────────────┐
    │  SILVER_CLIENT_DATA (Trusted / Normalized Data)        │
    │  - bt_crm_user_base                                    │
    │  - bt_email_logs                                       │
    │  - bt_whatsapp_provider                                │
    └────────────────────────────┬───────────────────────────┘
                                 │
                        (Attribution Engine)
                                 │
                                 ▼
    ┌────────────────────────────────────────────────────────┐
    │  GOLD_CLIENT_DATA (Business Analytics / Data Mart)     │
    │  - fct_attribution (PK: user_id, conversion_at)        │
    └────────────────────────────────────────────────────────┘

```

## Pilar C: Ingestão e Quality Gate (Python)

Antes de carregar os dados brutos de e-mail para a camada **Bronze**, os dados passam por uma validação estrita de qualidade através do script `json_quality_gate.py`.

### Regra do Quality Gate:

* O campo `message_details` contém um payload em formato JSON. Registros com JSON malformado ou nulos são inúteis para a análise de conversão.

* O script avalia cada linha do arquivo `raw_sfmc_email_logs.csv` e separa os dados em dois arquivos de saída:

  1. `sfmc_email_logs_valid.csv`: Registros íntegros prontos para a ingestão.

  2. `sfmc_email_logs_rejected.csv`: Registros corrompidos isolados para auditoria.

### Estrutura dos Arquivos:

* Script: `json_quality_gate.py`

* Entradas e Saídas:

  * Entrada: `./data/raw_data/raw_sfmc_email_logs.csv`

  * Dados Válidos: `./data/clean_data/sfmc_email_logs_valid.csv`

  * Dados Rejeitados: `./data/rejected_data/sfmc_email_logs_rejected.csv`

## Camadas de Dados no MySQL Workbench

### 1. Camada Bronze (`BRONZE_CLIENT_DATA`)

Nesta camada, os arquivos CSV limpos são importados utilizando a ferramenta **Table Data Import Wizard** do MySQL Workbench para preencher as tabelas de staging:

* `raw_crm_user_base`

* `raw_sfmc_email_logs`

* `raw_whatsapp_provider`

### 2. Camada Silver (`SILVER_CLIENT_DATA`)

Responsável pelo saneamento, padronização e timezone alignment. Os scripts de `UPSERT` limpam as inconsistências dos dados da camada Bronze e persistem o histórico atualizado:

* `bt_crm_user_base`: Contém a base dimensional de usuários e a data de conversão.

* `bt_email_logs`: Registros de e-mail com conversão temporal para o fuso de São Paulo (`America/Sao_Paulo` / UTC-3) e extração do `campaign_code` a partir da chave JSON.

* `bt_whatsapp_provider`: Logs de WhatsApp sanitizados com extração do `campaign_code` via Regex e padronização de telefone/email.

### 3. Camada Gold (`GOLD_CLIENT_DATA`)

Camada final voltada para consumo executivo e analytics.

* **Tabela**: `fct_attribution`

* **Chave Primária Composta**: `(user_id, conversion_at)`

## Pilar B: Regra de Negócio e Atribuição (Weighted Last Touch)

A atribuição de conversão responde à pergunta: *"Qual campanha gerou esta conversão?"*.

### Regras de Atribuição:

1. **Janela de Lookback de 7 Dias**: Apenas interações ocorridas nos 7 dias anteriores à data de conversão são elegíveis (`BETWEEN DATE_SUB(conversion_at, INTERVAL 7 DAY) AND conversion_at`).

2. **Prioridade em Conflitos de Canais**:

   * **Peso 1 (Maior)**: WhatsApp Read (`read`)

   * **Peso 2 (Médio)**: Email Click (`click`)

   * **Peso 3 (Menor)**: Email Open (`open`)

   * **Peso 4 (Disparo)**: Email Sent (`sent`) / WhatsApp Delivered (`delivered`) — elegíveis apenas se forem a única interação do período.

3. **Critério de Desempate**: Em caso de mesmo peso e mesmo timestamp, o critério de desempate no `ROW_NUMBER()` utiliza o `campaign_code ASC` para garantir **determinismo total**.

## Carga Incremental e Backfill

O script de carga da tabela `fct_attribution` utiliza a cláusula `INSERT ... ON DUPLICATE KEY UPDATE` garantindo **idempotência**:

* **Carga Inicial (Historico)**: Processa todas as conversões elegíveis da base.

* **Carga Diária (Incremental)**: Na rotina diária, basta ativar o filtro de janela temporal de conversões na CTE principal:

  ```
  WHERE c.conversion_at IS NOT NULL
    AND DATE(c.conversion_at) >= CURRENT_DATE() - INTERVAL 1 DAY
  
  ```

* **Estratégia de Backfill**: Para reprocessar um período específico (ex: últimos 30 dias), basta ajustar o intervalo da cláusula `WHERE` para o período desejado (ex: `BETWEEN CURRENT_DATE() - INTERVAL 30 DAY AND CURRENT_DATE()`). Como a chave primária composta é `(user_id, conversion_at)`, o comando atualiza as atribuições existentes sem duplicar linhas na Gold.

## Estrutura de Pastas do Repositório

```
.
├── json_quality_gate.py              # Script Python de Quality Gate (Pilar C)
├── README.md                         # Documentação completa da solução
└── scripts/
    ├── tables/                       # Scripts DDL de criação de tabelas
    │   ├── create_raw_crm_clients.sql
    │   ├── create_raw_email_logs.sql
    │   ├── create_raw_whatsapp_provider.sql
    │   ├── create_bt_crm_user_base.sql
    │   ├── create_bt_email_logs.sql
    │   ├── create_bt_whatsapp_provider.sql
    │   └── create_fct_attribution.sql
    └── pipelines/                    # Scripts DML de carga e Upsert
        ├── upsert_bt_crm_user_base.sql
        ├── upsert_bt_email_logs.sql
        ├── upsert_bt_whatsapp_provider.sql
        └── upsert_fct_attribution.sql

```
# CRM Data & Attribution Pipeline

Este repositório contém a solução completa para o pipeline de saneamento, ingestão, modelagem de dados e atribuição de conversões de CRM. 

A arquitetura foi implementada seguindo o modelo **Medallion (Bronze, Silver e Gold)** no **MySQL Workbench (v8.0)**, garantindo alta qualidade dos dados, rastreabilidade técnica, idempotência e suporte a cargas incrementais e backfill.

---

## Estrutura da Base de Dados Bruta

Os dados brutos utilizados como entrada para a construção do pipeline estão localizados no diretório `/data/raw_data`:

* `crm_user_base.csv`: Base dimensional de usuários, contendo e-mail, telefone e timestamp de conversão.
* `raw_sfmc_email_logs.csv`: Logs de eventos de disparos e interações de e-mail.
* `raw_whatsapp_provider.csv`: Logs de envios e leituras de mensagens via provedor de WhatsApp.

---

## Arquitetura da Solução

A solução divide-se em uma etapa de **Quality Gate** em Python e três camadas de dados (**Medallion Architecture**):

```text
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
   │  BRONZE_CLIENT_DATA (Raw Storage)                      │
   │  - raw_crm_user_base                                   │
   │  - raw_sfmc_email_logs                                 │
   │  - raw_whatsapp_provider                               │
   └────────────────────────────┬───────────────────────────┘
                                │
                       (Upsert & Cleaning)
                                │
                                ▼
   ┌────────────────────────────────────────────────────────┐
   │  SILVER_CLIENT_DATA (Cleaned & Standardized)           │
   │  - bt_crm_user_base                                    │
   │  - bt_email_logs                                       │
   │  - bt_whatsapp_provider                                │
   └────────────────────────────┬───────────────────────────┘
                                │
                      (Attribution Engine)
                                │
                                ▼
   ┌────────────────────────────────────────────────────────┐
   │  GOLD_CLIENT_DATA (Analytics Ready)                    │
   │  - fct_attribution (PK: user_id, conversion_at)        │
   └────────────────────────────────────────────────────────┘
```

---

## Requisitos e Pré-requisitos

Para executar o pipeline sem inconsistências, certifique-se de atender aos seguintes requisitos:

* **Python**: Versão `3.8` ou superior (testado no `3.10+`).
* **Dependências Python**: Bibliotecas descritas no `requirements.txt`:
  * `pandas` (para manipulação de dataframes e CSVs).
  * *Módulos nativos*: `json`, `logging`, `datetime`.
* **Banco de Dados**: MySQL Server e MySQL Workbench (Versão `8.0`).

---

## Como Executar o Pipeline

### 1. Camada de Qualidade de Dados (Quality Gate em Python)

Antes da carga na camada Bronze, os logs brutos de e-mail passam por uma validação estrita para identificar registros com o campo `message_details` corrompido ou vazio.

Para rodar o script:
```bash
python json_quality_gate.py
```

* **Regras de Validação**: O campo não pode ser nulo/vazio e deve possuir uma estrutura JSON válida.
* **Arquivos Gerados**:
  * `sfmc_email_logs_valid.csv`: Registros íntegros liberados para ingestão (`./data/clean_data/`).
  * `sfmc_email_logs_rejected.csv`: Registros corrompidos isolados para auditoria (`./data/rejected_data/`).

---

### 2. Ingestão e Modelagem SQL (MySQL Workbench)

Abra o MySQL Workbench em uma conexão com permissão para criar schemas, tabelas e realizar ingestões.

#### Camada Bronze (Raw)
1. Execute o script `scripts/schemas/create_schemas.sql` para criar a estrutura dos schemas (`BRONZE_CLIENT_DATA`, `SILVER_CLIENT_DATA` e `GOLD_CLIENT_DATA`).
2. Execute os DDLs localizados em `scripts/tables/BRONZE/`:
   * `create_raw_crm_clients.sql`
   * `create_raw_email_logs.sql`
   * `create_raw_whatsapp_provider.sql`
3. Importe os arquivos CSV correspondentes utilizando a ferramenta **Table Data Import Wizard** do MySQL Workbench:
   * `./data/raw_data/crm_user_base.csv` ➔ `raw_crm_user_base`
   * `./data/clean_data/sfmc_email_logs_valid.csv` ➔ `raw_sfmc_email_logs`
   * `./data/raw_data/raw_whatsapp_provider.csv` ➔ `raw_whatsapp_provider`

#### Camada Silver (Standardized)
1. Execute os DDLs localizados em `scripts/tables/SILVER/` (`create_bt_crm_user_base.sql`, `create_bt_email_logs.sql` e `create_bt_whatsapp_provider.sql`).
   * *Nesta etapa, adiciona-se o campo `user_id` e colunas de auditoria de carga/atualização (`AUD_INS_DTTM` e `AUD_UPD_DTTM`).*
2. Execute os scripts de **Upsert** localizados em `scripts/pipelines/SILVER/`:
   * `upsert_bt_crm_user_base.sql`: Normalização da base dimensional de usuários.
   * `upsert_bt_email_logs.sql`: Conversão de fuso horário UTC para o fuso de São Paulo (`America/Sao_Paulo` / UTC-3) e extração do `campaign_code` via JSON parsing.
   * `upsert_bt_whatsapp_provider.sql`: Limpeza de strings, regex para extração de `campaign_code` e padronização de telefone.

#### Camada Gold (Business & Attribution)
1. Execute o DDL de criação localizado em `scripts/tables/GOLD/create_fct_attribution.sql`.
2. Execute o pipeline final de atribuição em `scripts/pipelines/GOLD/upsert_fct_attribution.sql`.

---

## Regras de Negócio da Atribuição (`fct_attribution`)

A modelagem de atribuição de última conversão ponderada (*Weighted Last Touch*) segue as diretrizes:

1. **Janela de Lookback de 7 Dias**: Apenas interações ocorridas nos 7 dias anteriores ao momento da conversão são consideradas elegíveis:
   ```sql
   BETWEEN DATE_SUB(c.conversion_at, INTERVAL 7 DAY) AND c.conversion_at
   ```
2. **Matriz de Prioridade em Conflito de Canais**:
   * **Peso 1 (Maior)**: WhatsApp Lido (`read`)
   * **Peso 2**: E-mail Clicado (`click`)
   * **Peso 3**: E-mail Aberto (`open`)
   * **Peso 4 (Menor)**: E-mail Enviado (`sent`) / WhatsApp Entregue (`delivered`) — *Elegíveis apenas se forem o único evento no período.*
3. **Critério de Desempate**: Quando há empate absoluto de peso e timestamp no mesmo segundo, a função de janela `ROW_NUMBER()` utiliza `ORDER BY priority ASC, interaction_timestamp DESC, campaign_code ASC` para garantir determinismo.

---

## Carga Incremental e Estratégia de Backfill

Todos os scripts de pipeline utilizam a sintaxe `INSERT ... ON DUPLICATE KEY UPDATE`, garantindo a **idempotência** das operações:

* **Carga Inicial (Histórica)**: Executada com o script sem filtros de data para popular toda a série histórica.
* **Carga Diária (Incremental)**: Na rotina diária (ex: via Airflow/Cron), ativa-se o filtro incremental na CTE principal da query de atribuição:
  ```sql
  WHERE c.conversion_at IS NOT NULL
    AND DATE(c.conversion_at) >= CURRENT_DATE() - INTERVAL 1 DAY
  ```
* **Estratégia de Backfill**: Para reprocessar um período passado específico (ex: últimos 30 dias), ajusta-se a cláusula temporal para a janela desejada:
  ```sql
  AND DATE(c.conversion_at) BETWEEN CURRENT_DATE() - INTERVAL 30 DAY AND CURRENT_DATE()
  ```
  Como a chave primária da tabela fato é composta por `(user_id, conversion_at)`, o banco sobrescreverá/atualizará o registro sem gerar duplicidades.

---
*Para obter detalhes técnicos sobre o código, consulte os comentários embutidos nos arquivos `.py` e `.sql`.*
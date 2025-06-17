{% macro cleanup_staging_and_intermediate() %}
  {% set cleanup_query %}
    SELECT schema_name, table_name
    FROM duckdb_tables()
    WHERE
      schema_name = '{{ target.schema }}' 
      AND (table_name LIKE 'stg_%' OR table_name LIKE 'int_%')
  {% endset %}

  {% if execute %}
    {% set results = run_query(cleanup_query) %}
    {% for row in results %}
      {% set drop_sql = "DROP TABLE IF EXISTS " ~ row[0] ~ "." ~ row[1] ~ " CASCADE" %}
      {{ log("Dropping: " ~ row[0] ~ "." ~ row[1], info=True) }}
      {% do run_query(drop_sql) %}
    {% endfor %}
  {% endif %}
{% endmacro %}
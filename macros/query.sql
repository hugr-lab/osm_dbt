{% macro query(sql) %}
  {% set results = run_query(sql) %}
  {% if execute %}
    {% for row in results %}
      {{ log(row[0] ~ ": " ~ row[1], info=True) }}
    {% endfor %}
  {% endif %}
{% endmacro %}
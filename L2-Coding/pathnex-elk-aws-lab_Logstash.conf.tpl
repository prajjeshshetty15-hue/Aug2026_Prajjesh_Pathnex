
Coding practice:

input {
  beats { port => 5044 }
}

filter {
  json {
    source => "message"
    target => "pathnex"
    tag_on_failure => ["_pathnex_json_parse_failed"]
  }

  if "_pathnex_json_parse_failed" not in [tags] and [pathnex] {
    mutate {
      rename => {
        "[pathnex][service]"      => "service"
        "[pathnex][level]"        => "level"
        "[pathnex][endpoint]"     => "endpoint"
        "[pathnex][status_code]"  => "status_code"
        "[pathnex][latency_ms]"   => "latency_ms"
        "[pathnex][msg]"          => "msg"
        "[pathnex][ts]"           => "app_ts"
      }
      remove_field => ["pathnex"]
    }
  } else {
    grok {
      match => {
        "message" => "\[%%{LOGLEVEL:level}\]\s+%%{DATA:service}\s+endpoint=%%{DATA:endpoint}\s+status=%%{NUMBER:status_code:int}\s+latency_ms=%%{NUMBER:latency_ms:int}\s+%%{GREEDYDATA:msg}"
      }
      tag_on_failure => ["_pathnex_grok_failed"]
    }
  }

  mutate {
    lowercase => ["level"]
    convert   => { "status_code" => "integer" "latency_ms" => "integer" }
  }

  ruby {
    code => '
      sc = event.get("status_code")
      if sc
        event.set("is_error", sc.to_i >= 500)
        event.set("is_client_error", sc.to_i >= 400 && sc.to_i < 500)
      end
    '
  }
}

output {
  elasticsearch {
    hosts    => ["http://elasticsearch:9200"]
    user     => "elastic"
    password => "$${ELASTIC_PASSWORD}"
    index    => "pathnex-logs"
  }
  stdout { codec => rubydebug }
}




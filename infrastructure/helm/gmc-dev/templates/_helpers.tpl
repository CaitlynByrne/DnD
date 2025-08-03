{{/*
Expand the name of the chart.
*/}}
{{- define "gamemaster-companion.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "gamemaster-companion.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "gamemaster-companion.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "gamemaster-companion.labels" -}}
helm.sh/chart: {{ include "gamemaster-companion.chart" . }}
{{ include "gamemaster-companion.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "gamemaster-companion.selectorLabels" -}}
app.kubernetes.io/name: {{ include "gamemaster-companion.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "gamemaster-companion.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "gamemaster-companion.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Generate API database URL
*/}}
{{- define "gamemaster-companion.databaseUrl" -}}
{{- if and .Values.global.externalDatabase .Values.global.externalDatabase.enabled }}
{{- printf "postgresql://%s:%s@%s:%s/%s" .Values.global.externalDatabase.username .Values.global.externalDatabase.password .Values.global.externalDatabase.host (.Values.global.externalDatabase.port | toString) .Values.global.externalDatabase.database }}
{{- else }}
{{- $port := 5432 }}
{{- if and .Values.postgresql.primary .Values.postgresql.primary.service .Values.postgresql.primary.service.ports .Values.postgresql.primary.service.ports.postgresql }}
{{- $port = .Values.postgresql.primary.service.ports.postgresql }}
{{- end }}
{{- printf "postgresql://%s:%s@%s-postgresql:%s/%s" .Values.postgresql.auth.username .Values.postgresql.auth.postgresPassword (include "gamemaster-companion.fullname" .) ($port | toString) .Values.postgresql.auth.database }}
{{- end }}
{{- end }}

{{/*
Generate Redis URL
*/}}
{{- define "gamemaster-companion.redisUrl" -}}
{{- if and .Values.global.externalRedis .Values.global.externalRedis.enabled }}
{{- if and .Values.global.externalRedis.auth .Values.global.externalRedis.auth.enabled }}
{{- printf "redis://:%s@%s:%s/%s" .Values.global.externalRedis.auth.password .Values.global.externalRedis.host (.Values.global.externalRedis.port | toString) (.Values.global.externalRedis.database | toString) }}
{{- else }}
{{- printf "redis://%s:%s/%s" .Values.global.externalRedis.host (.Values.global.externalRedis.port | toString) (.Values.global.externalRedis.database | toString) }}
{{- end }}
{{- else }}
{{- $port := 6379 }}
{{- if and .Values.redis.master .Values.redis.master.service .Values.redis.master.service.ports .Values.redis.master.service.ports.redis }}
{{- $port = .Values.redis.master.service.ports.redis }}
{{- end }}
{{- if and .Values.redis.auth .Values.redis.auth.enabled }}
{{- printf "redis://:%s@%s-redis-master:%s/0" .Values.redis.auth.password (include "gamemaster-companion.fullname" .) ($port | toString) }}
{{- else }}
{{- printf "redis://%s-redis-master:%s/0" (include "gamemaster-companion.fullname" .) ($port | toString) }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Generate Elasticsearch URL
*/}}
{{- define "gamemaster-companion.elasticsearchUrl" -}}
{{- if and .Values.global.externalElasticsearch .Values.global.externalElasticsearch.enabled }}
{{- printf "http://%s:%s" .Values.global.externalElasticsearch.host (.Values.global.externalElasticsearch.port | toString) }}
{{- else }}
{{- $port := "9200" }}
{{- if and .Values.search.elasticsearch.service .Values.search.elasticsearch.service.ports .Values.search.elasticsearch.service.ports.http }}
{{- $port = .Values.search.elasticsearch.service.ports.http | toString }}
{{- end }}
{{- printf "http://%s-elasticsearch:%s" (include "gamemaster-companion.fullname" .) $port }}
{{- end }}
{{- end }}

{{/*
Generate vLLM API URL
*/}}
{{- define "gamemaster-companion.vllmUrl" -}}
{{- if .Values.ai.vllm.enabled }}
{{- printf "http://%s-vllm:%s" (include "gamemaster-companion.fullname" .) (.Values.ai.vllm.service.port | toString) }}
{{- else }}
{{- printf "http://localhost:8000" }}
{{- end }}
{{- end }}

{{/*
Common environment variables for all services
*/}}
{{- define "gamemaster-companion.commonEnv" -}}
- name: LOG_LEVEL
  value: {{ .Values.global.logLevel | quote }}
- name: DEBUG
  value: {{ .Values.global.debug | quote }}
- name: ENVIRONMENT
  value: {{ .Values.global.environment | default "development" | quote }}
- name: DOMAIN
  value: {{ .Values.global.domain | quote }}
{{- end }}

{{/*
Resource requirements template
*/}}
{{- define "gamemaster-companion.resources" -}}
{{- if .resources }}
resources:
  {{- if .resources.requests }}
  requests:
    {{- if .resources.requests.cpu }}
    cpu: {{ .resources.requests.cpu | quote }}
    {{- end }}
    {{- if .resources.requests.memory }}
    memory: {{ .resources.requests.memory | quote }}
    {{- end }}
  {{- end }}
  {{- if .resources.limits }}
  limits:
    {{- if .resources.limits.cpu }}
    cpu: {{ .resources.limits.cpu | quote }}
    {{- end }}
    {{- if .resources.limits.memory }}
    memory: {{ .resources.limits.memory | quote }}
    {{- end }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
Node selector template
*/}}
{{- define "gamemaster-companion.nodeSelector" -}}
{{- if .nodeSelector }}
nodeSelector:
  {{- toYaml .nodeSelector | nindent 2 }}
{{- end }}
{{- end }}

{{/*
Tolerations template
*/}}
{{- define "gamemaster-companion.tolerations" -}}
{{- if .tolerations }}
tolerations:
  {{- toYaml .tolerations | nindent 2 }}
{{- end }}
{{- end }}

{{/*
Affinity template
*/}}
{{- define "gamemaster-companion.affinity" -}}
{{- if .affinity }}
affinity:
  {{- toYaml .affinity | nindent 2 }}
{{- end }}
{{- end }}

{{/*
Security context template
*/}}
{{- define "gamemaster-companion.securityContext" -}}
{{- if .securityContext }}
securityContext:
  {{- toYaml .securityContext | nindent 2 }}
{{- end }}
{{- end }}

{{/*
Pod security context template
*/}}
{{- define "gamemaster-companion.podSecurityContext" -}}
{{- if .podSecurityContext }}
securityContext:
  {{- toYaml .podSecurityContext | nindent 2 }}
{{- end }}
{{- end }}
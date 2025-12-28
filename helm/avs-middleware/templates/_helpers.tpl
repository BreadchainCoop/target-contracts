{{/*
Expand the name of the chart.
*/}}
{{- define "avs-middleware.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "avs-middleware.fullname" -}}
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
{{- define "avs-middleware.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "avs-middleware.labels" -}}
helm.sh/chart: {{ include "avs-middleware.chart" . }}
{{ include "avs-middleware.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "avs-middleware.selectorLabels" -}}
app.kubernetes.io/name: {{ include "avs-middleware.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "avs-middleware.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "avs-middleware.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Get L1 RPC URL based on environment
*/}}
{{- define "avs-middleware.l1RpcUrl" -}}
{{- if eq .Values.environment "local" }}
{{- .Values.network.l1.rpcUrl }}
{{- else if eq .Values.environment "sepolia" }}
{{- default "https://1rpc.io/sepolia" .Values.network.l1.rpcUrl }}
{{- else if eq .Values.environment "holesky" }}
{{- default "https://1rpc.io/holesky" .Values.network.l1.rpcUrl }}
{{- else }}
{{- .Values.network.l1.rpcUrl }}
{{- end }}
{{- end }}

{{/*
Get L2 RPC URL based on environment
*/}}
{{- define "avs-middleware.l2RpcUrl" -}}
{{- if eq .Values.environment "local" }}
{{- .Values.network.l2.rpcUrl }}
{{- else if eq .Values.environment "sepolia" }}
{{- default "https://rpc.gnosischain.com" .Values.network.l2.rpcUrl }}
{{- else }}
{{- .Values.network.l2.rpcUrl }}
{{- end }}
{{- end }}

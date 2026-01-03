#!/usr/bin/env bash

set -e

src="https://huggingface.co/ggerganov/whisper.cpp"
pfx="resolve/main"

# Whisper models
models="tiny.en tiny base.en base small.en small medium.en medium large-v1 large-v2 large-v3 large-v3-turbo"

# list available models
list_models() {
        printf "\n"
        printf "  Available models:"
        for model in $models; do
                printf " %s" "$models"
        done
        printf "\n\n"
}

if [ "$#" -lt 1 ] || [ "$#" -gt 3 ]; then
    printf "Usage: %s <model> [--resume|-r]\n" "$0"
    list_models

    exit 1
fi

model=$1

if ! echo "$models" | grep -q -w "$model"; then
    printf "Invalid model: %s\n" "$model"
    list_models

    exit 1
fi

# download Core ML model

filename="ggml-$model-encoder.mlmodelc"
url="$src/$pfx/$filename"

resume=()
msg_pfx=
if [[ "$2" =~ ^-([cr]|-(continue|resume))$ ]]; then
    resume=( -c )
    msg_pfx="Attempting to resume downloading"
else
    msg_pfx="Downloading"
fi

printf "%s compiled Core ML model %s from '%s' ...\n" "$msg_pfx" "$model" "$src"

if [[ -f "$filename" ]]; then
    printf "Model %s already exists. Skipping download.\n" "$model"
    exit 1
fi

if [[ -f "$filename".zip ]] && [[ ! ${#resume[@]} ]]; then
    rm -f "$filename".zip
fi

echo aria2c --no-conf "${resume[@]}" -o "$filename".zip "$url".zip
aria2c --no-conf "${resume[@]}" -o "$filename".zip "$url".zip && \
    unzip "$filename".zip && \
    rm -f "$filename".zip && \
    printf "Done! Compiled model '%s' saved to '%s'\n" "$model" "$filename"

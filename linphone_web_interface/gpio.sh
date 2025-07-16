#!/bin/bash

PIN=7  # wPi номер пина
DEBOUNCE=200  # задержка в мс
TRIGGER_URL="http://localhost:8080/api/make_call"

gpio mode $PIN in
gpio mode $PIN up  # включить подтягивающий резистор

echo "🟢 Ожидание нажатия на кнопку на пине wPi $PIN..."

while true; do
  if [ "$(gpio read $PIN)" -eq 0 ]; then
    echo "📞 Кнопка нажата! Инициируем вызов..."
    curl -s "$TRIGGER_URL"
    sleep 1  # Подождём немного
    while [ "$(gpio read $PIN)" -eq 0 ]; do
      sleep 0.1  # ждём отпускания кнопки
    done
    sleep 1  # Защита от дребезга
  fi
  sleep 0.1
done

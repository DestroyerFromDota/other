#!/usr/bin/expect

set timeout -1

# Переменные для хранения данных
set jump_host1 "@172.16.143.50"
set jump_host2 "@172.16.129.51"
set password1 ""  ;# Первый пароль
set password2 ""  ;# Второй пароль
set timeout 120  ;# Sets the timeout to 120 seconds

# Открытие файла со списком хостов
set host_file [open "hosts.txt" r]
set hosts [split [read $host_file] "\n"]
close $host_file

# Итерация по каждому хосту в списке
foreach target_host $hosts {
    if {![string equal $target_host ""]} {
        # Подключение через джамп-хосты с автоматическим принятием ключа
        spawn ssh -o "StrictHostKeyChecking=no" -J $jump_host1,$jump_host2 $target_host

        # Ожидание командной строки после подключения
        expect {
            "$ " {
                send "sudo systemctl restart a1s-rsp\r"
            }
        }

        # Завершение сессии для первого прохода
        send "exit\r"
        expect eof  ;# Ожидание завершения сессии
    }
}

# Второй проход по тому же списку хостов для выполнения остальных команд
foreach target_host $hosts {
    if {![string equal $target_host ""]} {
        # Подключение через джамп-хосты с автоматическим принятием ключа
        spawn ssh -o "StrictHostKeyChecking=no" -J $jump_host1,$jump_host2 $target_host

        # Ожидание командной строки после подключения
        expect {
            "$ " {
                # Запуск grep для ожидания строки в логе
                send "sudo su - a1s-rsp -c \"grep --line-buffered 'use /opt/a1s-rsp/bin/input-pass' log/rsp.log\"\r"
            }
            timeout {
                send_user "Timeout occurred while waiting for the prompt after SSH to $target_host.\n"
                exit 1
            }
        }

        # Ожидание строки в логе, содержащей 'use /opt/a1s-rsp/bin/input-pass'
        expect {
            "use /opt/a1s-rsp/bin/input-pass" {
                # Когда строка найдена, продолжаем выполнение
            }
            timeout {
                send_user "Timeout while waiting for log message on $target_host.\n"
                exit 1
            }
        }

        # Смена пользователя и ввод паролей
        expect "$ " {
            send "sudo su - a1s-rsp -c \"/opt/a1s-rsp/bin/input-pass\"\r"
        }
        

        expect "Enter password/token (first key custodian):" {
            send "$password1\r"
        }
        
        expect "Enter password/token (second key custodian):" {
            send "$password2\r"
        }

        # Завершение сессии
        expect "$ " {
            send "exit\r"
        }
        
        expect eof  ;# Ожидание завершения сессии
    }
}


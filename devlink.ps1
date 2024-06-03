$MODULE_BASE_DIR = Split-Path $MyInvocation.MyCommand.Path -Parent
New-Item -ItemType Junction -Path "C:\Program Files\WindowsPowerShell\Modules\PsTaskManager"-Target "$MODULE_BASE_DIR"
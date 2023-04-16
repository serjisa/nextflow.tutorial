<p align="center"><img href="https://www.nextflow.io" src="https://raw.githubusercontent.com/nextflow-io/trademark/master/nextflow2014_no-bg.png" height="50">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<img href="https://www.docker.com" src="https://ml.globenewswire.com/Resource/Download/c83c4886-b215-4cf0-a973-64b8f65e7003" height="65"></p>

# Nextflow и Docker для анализа данных NGS
На этом семинаре мы разберём базовую механику взаимодействия с пайплайновым менеджером [Nextflow](https://www.nextflow.io) и с [Docker-контейнерами](https://www.docker.com). Это занятие не претендует на полноценный обзор всего функционала как Nextflow, так и Docker, и является в первую очередь первичной демонстрацией и введением для дальнейшего углубленного самостоятельного изучения (при необходимости). Для более глубокого погружения в мир пайплайнов (например, если вы сталкиваетесь с пайплайнами по работе на ежедневной основе) рекомендуем посмотреть [официальный курс Nextflow](https://training.nextflow.io).

### Организация семинара
Мы будем работать на платформе [Gitpod](https://www.gitpod.io), поэтому для начала обеспечьте себе там рабочий аккаунт. После того, как вы создадите аккаунт, перейдите по [ссылке](https://gitpod.io/#https://github.com/serjisa/nextflow.tutorial) и подождите, пока все необходимые дополнения установятся на виртуальную машину.

<img href="https://gitpod.io/#https://github.com/serjisa/nextflow.tutorial" src="https://img.shields.io/badge/Gitpod-%20Open%20in%20Gitpod-908a85?logo=gitpod">

### Почему не Google Colab?
Потому что функционал Google Colab, к сожалению, не позволяет использовать Docker. Однако если вы хотите поработать с Nextflow без контейнеров, то вы в целом можете воспользоваться Google Colab, семинар с использованием Nextflow в Google Colab вы можете найти [здесь](https://github.com/serjisa/transcriptomics.msu/blob/main/Семинары/01_Базовая_работа_с_прочтениями.ipynb).

## Nextflow
Для первого знакомства с Nextflow создадим некоторое подобие Hello, world!-скрипта. Для этого необходимо создать файл `my_pipeline.nf` со следующим содержимым:

```Groovy
#!/usr/bin/env nextflow

params.sra = "SRR11816045"
params.output = "results/"

log.info ""
log.info "  Q U A L I T Y   C O N T R O L  "
log.info "================================="
log.info "SRA number         : ${params.sra}"
log.info "Results location   : ${params.output}"
```

Дальше вы можете сделать скрипт исполняемым при помощи команды `chmod +x my_pipeline.nf` и запускать его напрямую (благодаря первой строчке скрипта Linux поймёт, что необходимо использовать Nextflow для исполнения этого скрипта).

Пока что в нём не описано никаких процессов и workflow, однако на этом примере можно разобрать, в каком формате вы можете передавать аргументы командной строки. Запустите этот скрипт без каких-либо аргументов, а потом передайте аргументы `--sra SRR11815971` и `--output output/`. Что поменялось?

Теперь добавим один простой процесс, который будет принимать на вход SRA-идентификатор и возвращать прямые ссылки на скачивание прочтений.

```Groovy
process GetLinks {
  input:
    val sra
  
  output:
    env links

  script:
    """
    links=\$(ffq --ftp ${sra} | jq -r '.[] | .url' | tr '\n' ' ')
    """
}

workflow {
  sra_ch = Channel.from( params.sra )
  GetLinks( sra_ch ) | view
}
```

Теперь при исполнении этого скрипта у нас будут выводиться прямые ссылки на скачивание файлов. Можно добавить ещё один процесс (и модифицировать workflow) таким образом, чтобы эти ссылки загружались при помощи `wget`:

```Groovy
process DownloadLinks {
  publishDir "${params.output}"

  input:
    val links

  script:
    """
    wget ${links}
    """
}

workflow {
  sra_ch = Channel.from( params.sra )
  GetLinks( sra_ch )
  DownloadLinks( GetLinks.out )
}
```

Также часто бывает, что нам необходимо процессировать сразу несколько экспериментов. Тогда можно поступить следующим образом: передавать в аргумент `--sra` список идентификаторов, разделённых запятыми, после чего создавать канал из листа, который образуется после разделения этого аргумента по запятым. В итоге итоговый пайплайн будет выглядеть следующим образом:

```Groovy
#!/usr/bin/env nextflow

params.sra = "SRR11816045"
ArrayList sra = params.sra.split(",")
params.output = "results/"

log.info ""
log.info "  Q U A L I T Y   C O N T R O L  "
log.info "================================="
log.info "SRA number         : ${sra}"
log.info "Results location   : ${params.output}"

process GetLinks {
  input:
    val sra
  
  output:
    env links

  script:
    """
    links=\$(ffq --ftp ${sra} | jq -r '.[] | .url' | tr '\n' ' ')
    """
}

process DownloadLinks {
  publishDir "${params.output}"

  input:
    val links

  script:
    """
    wget ${links}
    """
}

workflow {
  sra_ch = Channel.from( sra )
  GetLinks( sra_ch )
  DownloadLinks( GetLinks.out )
}
```

Nextflow создан для того, чтобы работать с биологическими данными, а потому там встроен ряд функций, которые облегчают жизнь в сценариях типа нашего. Вместо того, чтобы парсить ссылки на скачивание прочтений при помощи `ffq`, мы можем использовать встроенный функционал в виде `Channel.fromSRA` (а так же того факта, что при передаче ссылки в виде аргумента типа `path` файлы будут загружены автоматически):

```Groovy
#!/usr/bin/env nextflow

params.sra = "SRR11816045"
ArrayList sra = params.sra.split(",")
params.output = "results/"

log.info ""
log.info "  Q U A L I T Y   C O N T R O L  "
log.info "================================="
log.info "SRA number         : ${sra}"
log.info "Results location   : ${params.output}"

process DownloadLinks {
  publishDir "${params.output}"

  input:
    tuple val(sample_id), path(links)

  script:
    """
    echo "Files will be downloaded automatically."
    """
}


workflow {
  sra_ch = Channel.fromSRA(sra)
  DownloadLinks( sra_ch )
}
```

## Docker
Тут будет часть про Docker

### Использование Docker в Nextflow

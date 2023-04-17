<p align="center"><a href="https://www.nextflow.io"><img src="https://raw.githubusercontent.com/nextflow-io/trademark/master/nextflow2014_no-bg.png" height="50"></a>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://www.docker.com"><img src="https://ml.globenewswire.com/Resource/Download/c83c4886-b215-4cf0-a973-64b8f65e7003" height="65"></a></p>

# Nextflow и Docker для анализа данных NGS
На этом семинаре мы разберём базовую механику взаимодействия с пайплайновым менеджером [Nextflow](https://www.nextflow.io) и с [Docker-контейнерами](https://www.docker.com). Это занятие не претендует на полноценный обзор всего функционала как Nextflow, так и Docker, и является в первую очередь первичной демонстрацией и введением для дальнейшего углубленного самостоятельного изучения (при необходимости). Для более глубокого погружения в мир пайплайнов (например, если вы сталкиваетесь с пайплайнами по работе на ежедневной основе) рекомендуем посмотреть [официальный курс Nextflow](https://training.nextflow.io).

### Организация семинара
Мы будем работать на платформе [Gitpod](https://www.gitpod.io), поэтому для начала обеспечьте себе там рабочий аккаунт. После того, как вы создадите аккаунт, перейдите по [ссылке](https://gitpod.io/#https://github.com/serjisa/nextflow.tutorial) и подождите, пока все необходимые дополнения установятся на виртуальную машину.

<a href="https://gitpod.io/#https://github.com/serjisa/nextflow.tutorial"><img src="https://img.shields.io/badge/Gitpod-%20Open%20in%20Gitpod-908a85?logo=gitpod"></a>

### Почему не Google Colab?
Потому что функционал Google Colab, к сожалению, не позволяет использовать Docker. Однако если вы хотите поработать с Nextflow без контейнеров, то вы в целом можете воспользоваться Google Colab, семинар с использованием Nextflow в Google Colab вы можете найти [здесь](https://github.com/serjisa/transcriptomics.msu/blob/main/Семинары/01_Базовая_работа_с_прочтениями.ipynb).

## Nextflow
Для первого знакомства с Nextflow создадим некоторое подобие Hello, world!-скрипта. Для этого необходимо создать файл `my_pipeline.nf` со следующим содержимым:
  
```Groovy
#!/usr/bin/env nextflow

params.sra = "SRR11816045"
params.output = "results/"

log.info ""
log.info "   W G S    A L I G N M E N T   "
log.info "================================"
log.info "SRA IDs              : ${params.sra}"
log.info "Output directory     : ${params.output}"
log.info ""
```

Дальше вы можете сделать скрипт исполняемым при помощи команды `chmod +x my_pipeline.nf` и запускать его напрямую (благодаря первой строчке скрипта Linux поймёт, что необходимо использовать Nextflow для исполнения этого скрипта).

Пока что в нём не описано никаких процессов и workflow, однако на этом примере можно разобрать, в каком формате вы можете передавать аргументы командной строки. Запустите этот скрипт без каких-либо аргументов, а потом передайте аргументы `--sra SRR11815971` и `--output output/`. Что поменялось?

Теперь добавим один простой процесс, который будет принимать на вход SRA-идентификатор и возвращать прямые ссылки на скачивание прочтений.
  
```Groovy
process GetLinks {
  input:
    val sra_id
  
  output:
    env links

  script:
    """
    links=\$(ffq --ftp ${sra_id} | jq -r '.[] | .url' | tr '\n' ' ')
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
    
  output:
    path "*.fastq.gz"

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

Также часто бывает, что нам необходимо процессировать сразу несколько экспериментов. Тогда можно поступить следующим образом: передавать в аргумент `--sra` список идентификаторов, разделённых запятыми, после чего создавать канал из листа, который образуется после разделения этого аргумента по запятым. Давайте объединим все описанные выше элементы пайплайна и по итогу получим полный готовый скрипт для запуска пайплайна.
  
```Groovy
#!/usr/bin/env nextflow

params.sra = "SRR11816045,SRR11815971"
params.output = "results/"
ArrayList sra = params.sra.split(",")

log.info ""
log.info "   W G S    A L I G N M E N T   "
log.info "================================"
log.info "SRA IDs              : ${sra}"
log.info "Output directory     : ${params.output}"
log.info ""

process GetLinks {
  input:
    val sra_id
  
  output:
    tuple val(sra_id), env(links)

  script:
    """
    links=\$(ffq --ftp ${sra_id} | jq -r '.[] | .url' | tr '\n' ' ')
    """
}

process DownloadLinks {
  publishDir "${params.output}"

  input:
    tuple val(sra_id), val(links)
    
  output:
    path "${sra_id}"

  script:
    """
    mkdir ${sra_id} && cd ${sra_id} && wget ${links}
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
process DownloadLinks {
  publishDir "${params.output}"

  input:
    tuple val(sample_id), path(links)
  
  output:
    path "${sample_id}"

  script:
    """
    mkdir ${sample_id}
    mv ${links} ${sample_id}
    """
}


workflow {
  sra_ch = Channel.fromSRA( sra, apiKey:"<NCBI_API_KEY>" )
  DownloadLinks( sra_ch )
}
```

#### Задание
Напишите скрипт, который будет брать на вход ссылку на референсный геном, а потом делать из него индекс для bowtie2 (команда `bowtie2-build`).

<details>
  <summary><b>Решение</b></summary>
  
  ```Groovy
  #!/usr/bin/env nextflow

  params.genome = "https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/005/845/GCF_000005845.2_ASM584v2/GCF_000005845.2_ASM584v2_genomic.fna.gz"
  params.output = "results/"

  log.info ""
  log.info "   W G S    A L I G N M E N T   "
  log.info "================================"
  log.info "Genome link          : ${params.genome}"
  log.info "Output directory     : ${params.output}"
  log.info ""

  process BuildIndex {
    publishDir "${params.output}"

    input:
      path genome_link

    output:
      path "index"

    script:
      """
      if [[ "${genome_link}" == *.gz ]]
      then
          gunzip -c ${genome_link} > genome.fasta
      else
          mv ${genome_link} genome.fasta
      fi
      mkdir index
      bowtie2-build genome.fasta index/index
      """
  }


  workflow {
    genome_ch = Channel.from( params.genome )
    BuildIndex( genome_ch )
  }
  ```
  
</details>

Для того, чтобы получить на выход .html-репорт об исполнении пайплайна, необходимо добавить аргумент `-with-report <report-name.html>`, а для отрисовки графа связи процессов пайплайна, — аргумент `-with-dag <graph-name.pdf>`.

#### Задание
Найдите скрипт `mapping_pipeline.nf` и оптимизируйте его с использованием `Channel.fromSRA`, автоматической загрузки исполняемых файлов и так же директивы `cpus`.

<details>
  <summary><b>Решение</b></summary>
  
  ```Groovy
  #!/usr/bin/env nextflow

  params.sra = "SRR11816045,SRR11815971"
  params.genome_link = "https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/005/845/GCF_000005845.2_ASM584v2/GCF_000005845.2_ASM584v2_genomic.fna.gz"
  params.n_cores = 4
  params.output = "results/"

  ArrayList sra = params.sra.split(",")

  log.info ""
  log.info "   W G S    A L I G N M E N T   "
  log.info "================================"
  log.info "SRA IDs              : ${sra}"
  log.info "Genome link          : ${params.genome_link}"
  log.info "Number of cores      : ${params.n_cores}"
  log.info "Output directory     : ${params.output}"
  log.info ""

  process BuildIndex {
    input:
      path genome

    output:
      path "index"

    script:
      """
      if [[ "${genome}" == *.gz ]]
      then
          gunzip -c ${genome} > genome.fasta
      else
          mv ${genome} genome.fasta
      fi
      mkdir index
      bowtie2-build genome.fasta index/index
      """
  }

  process DownloadReads {
    input:
      tuple val(sample_id), path(reads)

    output:
      path "${sample_id}"

    script:
      """
      mkdir ${sample_id}
      mv ${reads} ${sample_id}/
      """
  }

  process FastQC {
    input:
      path sample_id

    output:
      path "${sample_id}/fastqc/*"

    script:
      """
      mkdir ${sample_id}/fastqc
      fastqc --noextract -o ${sample_id}/fastqc ${sample_id}/*.fastq.gz
      """
  }

  process Mapping {
    cpus params.n_cores

    publishDir "${params.output}"

    input:
      path index
      path sample_id

    output:
      path "${sample_id}"

    script:
      """
      bowtie2 --no-unal -p ${params.n_cores} -x ${index}/index \
          -1 ${sample_id}/*_1.fastq.gz -2 ${sample_id}/*_2.fastq.gz \
          -S ${sample_id}/${sample_id}.sam 2> ${sample_id}/${sample_id}.log
      samtools view -bS \
          ${sample_id}/${sample_id}.sam > ${sample_id}/${sample_id}.bam
      rm ${sample_id}/${sample_id}.sam
      """
  }

  process MultiQC {
    publishDir "${params.output}"

    input:
      path alignments
      path fastqc

    output:
      path "multiqc_report.html"

    script:
      """
      multiqc .
      """
  }

  workflow {
    sra_ch = Channel.fromSRA( sra, apiKey:"<NCBI_API_KEY>" )
    BuildIndex( params.genome_link )
    DownloadReads( sra_ch )
    FastQC( DownloadReads.out )
    Mapping( BuildIndex.out, DownloadReads.out )
    MultiQC( Mapping.out.collect(), FastQC.out.collect() )
  }
  ```
  
</details>

## Docker
Docker — это система контейнеризации, которая позволяет использовать образы, подобные виртуальным машинам. Это позволяет повысить удобство пользования инструментами, а также увеличивает воспроизводимость результатов. Взаимодействие с Docker на базовом уровне примерно такое же, как и с любой программой. Необходимо набрать команду `docker run <image> <command> <arguments>`. Так же можно запустить Docker в интерактивном режиме, что по механике взаимодействия будет подобно тому, что вы запустили другую ОС при помощи терминала. Попробуем зайти в образ с SRA-Tools:
```Shell
docker run -it ncbi/sra-tools
```
Теперь мы видим перед нами командную строку, в которой мы можем набрать команду для загрузки прочтений:
```Shell
fastq-dump --gzip --split-3 SRR11816045
```
В результате у нас загрузятся прочтения из этого SRA-эксперимента. Важно заметить, что SRA-Tools не установлены в системе, с которой мы работаем. Для выхода из контейнера можно воспользоваться командой `exit`. После вызова контейнера он оказывается в локальном репозитории. Все доступные контейнеры можно посмотреть при помощи команды `docker images`. Удалить контейнер можно при помощи команды `docker rmi --force <IMAGE_ID>`.

Попробуем не заходить в Docker, а вызвать следующую команду:

```Shell
docker run ncbi/sra-tools fastq-dump --gzip --split-3 SRR11816045
```

Кажется, что ничего не произошло, однако это не так — внутри контейнера началась загрузка файлов (которые, правда, так и остались внутри контейнера). Для того, чтобы иметь доступ к файлам в контейнере (а также передавать файлы в контейнер), необходимо примонтировать директорию, которая будет коммуницировать между вашей файловой системой и контейнером.

```Shell
mkdir reads
cd reads
docker run --volume $PWD:$PWD --workdir $PWD ncbi/sra-tools \
    fastq-dump --gzip --split-3 --outdir $PWD SRR11816045
```

Теперь вы видите, что загрузка происходит в директорию, в которой вы находитесь (`reads`). Использование контейнеров очень сильно помогает в случаях, когда программа требует большое количество зависимостей (попробуйте запустить без контейнеров [BUSCO](https://busco.ezlab.org)).

### Dockerfile
Для того, чтобы сделать собственный Docker-образ, необходимо сделать `Dockerfile`, а после этого на его основе сконструировать образ при помощи команды `docker build -t <IMAGE_NAME> .`. Пример Dockerfile, при помощи которого можно построить контейнер, содержащий все программы из сегодняшнего семинара:

```dockerfile
# An initial image will be based on Ubuntu 18.04
FROM ubuntu:18.04

# We can add info about the maintainer of the image
MAINTAINER Sergey Isaev <serj.hoop@gmail.com>

# Install packages and tools via apt
RUN apt-get update && apt-get install --yes --no-install-recommends \
    make jq gcc libpq-dev wget curl locales vim-tiny git cmake \
    build-essential gcc-multilib perl python3 python3-pip locales-all \
    libbz2-dev zlib1g-dev libncurses5-dev libncursesw5-dev \
    liblzma-dev gzip zip unzip fastqc samtools python3-setuptools \
    python-dev python3-dev python3-venv python3-wheel bowtie2
 
# Install Python packages
RUN python3 -m pip install -U --force-reinstall pip
RUN python3 -m pip install wheel ffq multiqc

# Setting up language parameters
RUN sed -i -e "s/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/" /etc/locale.gen && \
    dpkg-reconfigure --frontend=noninteractive locales && \
    update-locale LANG=en_US.UTF-8
ENV LC_ALL en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US.UTF-8
```

#### Задание
Попробуйте на основе докер-образа с сегодняшнего занятия (`sisaev64/nextflow-tutorial:0.1.1`) сделать образ с программой Salmon (`apt-get install salmon`). 

<details>
  <summary><b>Решение</b></summary>
  
  ```dockerfile
  FROM sisaev64/nextflow-tutorial:0.1.1
  RUN apt-get install --yes --no-install-recommends salmon
  ```
  
</details>

### Использование Docker в Nextflow
Существует два сценария использования Docker в Nextflow.

В первом случае вы можете заранее создать образ со всеми необходимыми инструментами, после чего запустить Nextflow с флагом `-with-docker <IMAGE_NAME>`.

Во втором случае вы можете использовать образы для каждого из процессов пайплайна, тогда необходимо в начале процесса явно прописать название образа, который в нём используется:
```Groovy
process foo {
  container "${container_name}"
}
```

#### Задание
Добавьте в каждый из элементов пайплайна, который мы сделали на занятие, свой контейнер (найдите контейнеры, находящиеся в открытом доступе). Протестируйте работу пайплайна с этими контейнерами.

<details>
  <summary><b>Решение</b></summary>
  
  ```Groovy
  #!/usr/bin/env nextflow

  params.sra = "SRR11816045"
  params.genome_link = "https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/005/845/GCF_000005845.2_ASM584v2/GCF_000005845.2_ASM584v2_genomic.fna.gz"
  params.n_cores = 4
  params.output = "results/"

  ArrayList sra = params.sra.split(",")

  log.info ""
  log.info "   W G S    A L I G N M E N T   "
  log.info "================================"
  log.info "SRA IDs              : ${sra}"
  log.info "Genome link          : ${params.genome_link}"
  log.info "Number of cores      : ${params.n_cores}"
  log.info "Output directory     : ${params.output}"
  log.info ""

  process BuildIndex {
    container "biocontainers/bowtie2:v2.4.1_cv1"

    input:
      path genome

    output:
      path "index"

    script:
      """
      if [[ "${genome}" == *.gz ]]
      then
          gunzip -c ${genome} > genome.fasta
      else
          mv ${genome} genome.fasta
      fi
      mkdir index
      bowtie2-build genome.fasta index/index
      """
  }

  process DownloadReads {
    input:
      tuple val(sample_id), path(reads)

    output:
      path "${sample_id}"

    script:
      """
      mkdir ${sample_id}
      mv ${reads} ${sample_id}/
      """
  }

  process FastQC {
    container "biocontainers/fastqc:v0.11.9_cv8"

    input:
      path sample_id

    output:
      path "${sample_id}/fastqc/*"

    script:
      """
      mkdir ${sample_id}/fastqc
      fastqc --noextract -o ${sample_id}/fastqc ${sample_id}/*.fastq.gz
      """
  }

  process Mapping {
    container "biocontainers/bowtie2:v2.4.1_cv1"

    cpus params.n_cores

    publishDir "${params.output}"

    input:
      path index
      path sample_id

    output:
      path "${sample_id}"

    script:
      """
      bowtie2 --no-unal -p ${params.n_cores} -x ${index}/index \
          -1 ${sample_id}/*_1.fastq.gz -2 ${sample_id}/*_2.fastq.gz \
          -S ${sample_id}/${sample_id}.sam 2> ${sample_id}/${sample_id}.log
      samtools view -bS \
          ${sample_id}/${sample_id}.sam > ${sample_id}/${sample_id}.bam
      rm ${sample_id}/${sample_id}.sam
      """
  }

  process MultiQC {
    container "staphb/multiqc:1.8"

    publishDir "${params.output}"

    input:
      path alignments
      path fastqc

    output:
      path "multiqc_report.html"

    script:
      """
      multiqc .
      """
  }

  workflow {
    sra_ch = Channel.fromSRA( sra, apiKey:"41c04bd6385a2dca753ada0eb22f54f7d309" )
    BuildIndex( params.genome_link )
    DownloadReads( sra_ch )
    FastQC( DownloadReads.out )
    Mapping( BuildIndex.out, DownloadReads.out )
    MultiQC( Mapping.out.collect(), FastQC.out.collect() )
  }
  ```
  
</details>

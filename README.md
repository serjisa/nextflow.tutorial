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
Тут будет часть про Docker

### Использование Docker в Nextflow

# Nextflow и Docker для анализа данных NGS

Воспроизведение анализа с семинара в три команды:
```bash
git clone https://github.com/serjisa/nextflow.tutorial.git
docker pull sisaev64/nextflow-tutorial:0.1.1
nextflow run nextflow.tutorial/mapping_pipeline.nf \
    -with-report nextflow_report.html \
    -with-dag flowchart.pdf \
    -with-docker sisaev64/nextflow-tutorial:0.1.1
```

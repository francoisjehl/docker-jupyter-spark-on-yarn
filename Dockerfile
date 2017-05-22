FROM centos:7
LABEL maintainer "Francois Jehl <f.jehl@criteo.com>"

# Software versions can be provided at build time
ARG SPARK_VERSION=2.1.0
ARG HADOOP_VERSION=2.6
ARG SCALA_VERSION=2.11.8
ARG JAVA_VERSION=1.8.0

# Java and Scala
RUN yum install -y \
      wget \
      java-${JAVA_VERSION}-openjdk
RUN wget --quiet http://downloads.lightbend.com/scala/${SCALA_VERSION}/scala-${SCALA_VERSION}.rpm
RUN yum install -y \
      scala-${SCALA_VERSION}.rpm
ENV JAVA_HOME "/usr/lib/jvm/java"
ENV PATH "$PATH:/usr/share/scala/bin"

# Spark CDH5 runtime and Kerberos clients
RUN wget --quiet http://d3kbcqa49mib13.cloudfront.net/spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz
RUN tar -xzf spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz && mv spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION} /usr/local/spark
ENV PATH "$PATH:/usr/local/spark/bin"
ENV SPARK_HOME "/usr/local/spark"
ENV SPARK_SUBMIT_OPTS "-Djava.security.krb5.conf=/etc/krb5.conf"
ENV HADOOP_CONF_DIR "/etc/hadoop/conf"
ENV PYTHONPATH="${SPARK_HOME}/python"

# R
RUN yum install -y \
      epel-release
RUN yum repolist
RUN yum install -y \
      R \
      libcurl-devel \
      openssl-devel

RUN R --quiet -e "dir.create(paste(R.home('doc'), '/html', sep=''))"

#SparklyR
RUN R --quiet -e " \
      install.packages(c('devtools', 'dplyr'), repos='https://cran.univ-paris1.fr/') \
" 2>/dev/null
RUN R --quiet -e " \
      devtools::install_github('rstudio/sparklyr', dependencies=TRUE) \
" 2>/dev/null

# R Kernel
RUN R --quiet -e " \
      devtools::install_github('IRkernel/IRkernel') \
" 2>/dev/null

# Plotly Visualization Library
RUN R --quiet -e " \
      devtools::install_github('tidyverse/purrr') \
" 2>/dev/null
RUN R --quiet -e " \
      install.packages(c('plotly'), \ 
        repos='https://cran.univ-paris1.fr/'); \
" 2>/dev/null

# Miniconda
RUN yum install -y \
      bzip2

RUN wget --quiet https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh
RUN chmod +x Miniconda3-latest-Linux-x86_64.sh
RUN bash Miniconda3-latest-Linux-x86_64.sh -b
ENV PATH="/root/miniconda3/bin:${PATH}"

# Python
# 3.x
COPY python3.yml /tmp/python3.yml
RUN conda env create -f /tmp/python3.yml
# 2.x
COPY python2.yml /tmp/python2.yml
RUN conda env create -f /tmp/python2.yml

#Jupyter Kernel registration
RUN mkdir /root/jupyter
# Python 3.x
RUN source activate python3 && \
    ipython kernel install --user
# Python 2.x
RUN source activate python2 && \
    ipython kernel install --user
# R
RUN source activate python3 && \
    R --quiet -e " \
      IRkernel::installspec(user = FALSE) \
" 2>/dev/null

# Kerberos clients
RUN yum install -y \
      kstart \
      krb5-workstation 

# Supervisor
COPY supervisor.yml /tmp/supervisor.yml
RUN conda env create -f /tmp/supervisor.yml

COPY k5startd /usr/local/bin/k5startd
COPY jupyterd /usr/local/bin/jupyterd
COPY jupyterd.sv.conf /etc/supervisor/conf.d/
COPY k5startd.sv.conf /etc/supervisor/conf.d/
COPY supervisord.conf /etc/supervisord.conf

# Fix for LZO (http://stackoverflow.com/questions/23441142/class-com-hadoop-compression-lzo-lzocodec-not-found-for-spark-on-cdh-5) 
RUN yum install -y \
  lzo \
  lzo-devel

RUN wget --quiet http://central.maven.org/maven2/org/anarres/lzo/lzo-hadoop/1.0.5/lzo-hadoop-1.0.5.jar
RUN mv lzo-hadoop-1.0.5.jar ~

# Spark global config file
RUN yum install -y \
     gettext
COPY spark-defaults.conf.template /usr/local/spark/conf/spark-defaults.conf.template

# Housekeeping
RUN rm scala-*.rpm && rm spark-*.tgz

# Necessary port (Spark UI, Spark Driver ports and Jupyter Console)
EXPOSE 4040
EXPOSE 7001:7005
EXPOSE 8888

#Starting supervisor
COPY supervisord /usr/local/bin/supervisord
ENTRYPOINT ["/usr/local/bin/supervisord"]


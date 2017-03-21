FROM centos:7
LABEL maintainer "Francois Jehl <f.jehl@criteo.com>"

# Software versions can be provided at build time
ARG SPARK_VERSION=2.0.0
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

# Some of the dependencies require EPELs
RUN yum install -y \
      epel-release
RUN yum repolist
RUN yum install -y \
      R \
      libcurl-devel \
      openssl-devel

RUN R --quiet -e " \
      install.packages('sparklyr', repos='https://cran.univ-paris1.fr/') \
" 2>/dev/null

# Jupyter
RUN yum install -y \
      python-devel \
      python-pip
RUN pip install jupyter
RUN R --quiet -e " \
      install.packages(c('repr', 'IRdisplay', 'evaluate', 'crayon', 'pbdZMQ', 'devtools', 'uuid', 'digest'), repos='https://cran.univ-paris1.fr/'); \
"  2>/dev/null
RUN R --quiet -e " \
      devtools::install_github('IRkernel/IRkernel') \
"  2>/dev/null
RUN R --quiet -e " \
      IRkernel::installspec(user = FALSE) \
" 2>/dev/null

# Kerberos clients
RUN yum install -y \
      kstart \
      krb5-workstation 

# SupervisorD
RUN yum install -y \
      python-setuptools
RUN easy_install supervisor
COPY k5startd /usr/local/bin/k5startd
COPY jupyterd /usr/local/bin/jupyterd
COPY jupyterd.sv.conf /etc/supervisor/conf.d/
COPY k5startd.sv.conf /etc/supervisor/conf.d/
COPY supervisord.conf /etc/supervisord.conf

# Fix for LZO
RUN yum install -y \
  lzo \
  lzo-devel

RUN wget --quiet http://central.maven.org/maven2/org/anarres/lzo/lzo-hadoop/1.0.5/lzo-hadoop-1.0.5.jar
RUN mv lzo-hadoop-1.0.5.jar ~
RUN echo -e "spark.driver.extraClassPath /root/lzo-hadoop-1.0.5.jar\nspark.executor.extraClassPath /root/lzo-hadoop-1.0.5.jar" \
  > /usr/local/spark/conf/spark-defaults.conf

#Starting supervisor
CMD ["/usr/bin/supervisord", "-n"]


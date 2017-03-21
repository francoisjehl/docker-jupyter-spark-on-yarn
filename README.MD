docker build -t fjehl/docker-spark .

docker run -ti \
  --net host \
  -v <path_containing_hadoop_conf>:/etc/hadoop \
  -v <krb5_conf_file>:/etc/krb5.conf \
  -v <hive_site_xml_file>:/usr/local/spark/conf/hive-site.xml \
  -e KRB_LOGIN=<user>@CRITEOIS.LAN \
  -e KRB_PASSWORD=<password> \
  fjehl/docker-spark


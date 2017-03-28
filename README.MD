# docker-jupyter-spark-on-yarn
A convenient docker container to run Jupyter notebooks with Spark on Yarn.
Can be found on Docker Hub at https://hub.docker.com/r/fjehl/docker-jupyter-spark-on-yarn/

## Build it

Make sure you have docker installed.
Then build the image from within the folder.

```
docker build -t fjehl/docker-jupyter-spark-on-yarn .
```

Once built, you can run it, once you provide a set of configurations:

You need to supply 3 external volumes for it to run

 - **Hadoop configuration files** such as yarn-site.xml to be mounted in the host as /etc/hadoop/conf/*
 - **krb5.conf** to be mounted in the guest as /etc/krb5.conf
 - **hive-site.xml** to be mounted in the guest as /usr/local/spark/conf/hive-site.xml


The container also needs your Kerberos **credentials** as environment variables
 - KRB_LOGIN should be your fully qualified Kerberos login (j.doe@REALM.COM)
 - KRB_PASSWORD for your password

Then you can run it as follows:

```
docker run -ti \
  --net host \
  -v <path_containing_hadoop_conf>:/etc/hadoop \
  -v <krb5_conf_file>:/etc/krb5.conf \
  -v <hive_site_xml_file>:/usr/local/spark/conf/hive-site.xml \
  -e KRB_LOGIN=<user> \
  -e KRB_PASSWORD=<password> \
  fjehl/docker-jupyter-spark-on-yarn
```
No worries about credential expiration: the docker instance embeds k5start and keeps your ticket active.

## Use it

Once the container is started, it will display a link in the console. Click on it, and enter Jupyter.
Start a R notebook.
You can test all the features (read from hive, train model, write to HDFS, with a script like the following).

```
# Connect to Yarn
library(sparklyr)
library(dplyr)
require(DBI)
sc <- spark_connect(master = "yarn-client")


# Get data from Hive
dbGetQuery(sc,'USE fjehl')
mtcars_df <- tbl(sc,"mtcars")

# Train a linreg model
mt_cars_partitions <- mtcars_df %>%
  sdf_partition(training = 0.5, test = 0.5, seed = 1099)

linreg_model <- mt_cars_partitions$training %>%
  ml_linear_regression(response = "mpg", features = c("wt", "cyl"))

# Graph the results
library(plotly)
result <- select(sdf_predict(linreg_model, mt_cars_partitions$test), wt, cyl, mpg, prediction)
p <- plot_ly(collect(result), x = ~wt, y = ~cyl, z = ~mpg) %>%
  add_markers(name='actual') %>%
  add_markers(z=~prediction, name='prediction') %>%
  layout(scene = list(xaxis = list(title = 'Weight'),
                     yaxis = list(title = 'Cylinder'),
                     zaxis = list(title = 'Gross horsepower')))
embed_notebook(p)

# Write the results in HDFS
spark_write_csv(result, header=FALSE, path="hdfs://root/user/f.jehl/spark_results")
dbGetQuery(sc,"CREATE EXTERNAL TABLE IF NOT EXISTS fjehl.results(
  wt double,
  cyl int,
  mpg double,
  prediction double)
ROW FORMAT DELIMITED
  FIELDS TERMINATED BY ','
  LINES TERMINATED BY '\n'
STORED AS TEXTFILE
LOCATION
  'hdfs://root/user/f.jehl/spark_results'")
dbGetQuery(sc,"SELECT * FROM fjehl.results")
```

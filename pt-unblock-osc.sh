#!/bin/sh

#Error Handling: Checking the number of arguments entered by user
[ $# -ne 2 ] && echo "Usage: $0 <db name> <table name>" && exit 1

#Error Handling: Checking if the entered schema and table exists
out1=$(echo "select 1 from tables where table_schema = \"${1}\" and table_name = \"${2}\" limit 1;" | mysql --skip-column-names information_schema)
[ "$out1" != "1" ] && echo "ERROR! Exiting!! Entered table does not exist.Please check" && exit 1

#Error Handling: Checking if the Audit table required for operation of script exists or not
out2=$(echo "select 1 from tables where table_schema = \"mysql\" and table_name = \"PTOSC_KILLED_PROCESSLIST\" limit 1;" | mysql --skip-column-names information_schema)
[ "$out2" != "1" ] && echo "ERROR! Exiting!! Table PTOSC_KILLED_PROCESSLIST does not exist in mysql db.Please check" && exit 1

dbName=$1 #Database Name Argument 1
tabName=$2 #Table Name Argument 2

while true;
do
blocking = $(mysql --skip-column-names -BNe "select count(1) from information_schema.processlist where DB = \"$dbName\" and USER = 'system user' and STATE = 'Waiting for table metadata lock' limit 1;") 
while [ $blocking -eq 1 ]
do
        mysql -e "insert into mysql.PTOSC_KILLED_PROCESSLIST(id,user,host,db,command,time,state,info,time_ms,rows_sent,rows_examined,tid) select * from information_schema.processlist            where user not in (\"system user\") and command not in (\"Sleep\") and state not like \"%metadata lock%\" and db = \"${dbName}\"         and lower(replace(info,\"\`\",\" \")) like lower(\"% ${tabName} %\") order by time desc limit 1"
        mysql -BNe 'select group_concat(concat('\''kill '\'',id,'\'';'\'') separator '\'' '\'') from mysql.PTOSC_KILLED_PROCESSLIST where killed = 0 order by created_at desc limit 1; update mysql.PTOSC_KILLED_PROCESSLIST set killed = 1 where killed = 0;' |sed 's/NULL//g' |mysql
        sleep 1
        blocking=$(mysql --skip-column-names -BNe "select count(1) from information_schema.processlist where DB = \"$dbName\" and USER = 'system user' and STATE = 'Waiting for table metadata lock' limit 1;")
done
sleep 1
done


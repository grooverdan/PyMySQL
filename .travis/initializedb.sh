#!/bin/bash

#debug
set -x
#verbose
set -v

if [ ! -z "${DBTARBALL}" ]; then
    # disable existing database server in case of accidential connection
    sudo service mysql stop

    pushd "$HOME"
    MYSQL_BASE=${DBTARBALL##*/}
    if [ ! -d tarballcache ]; then
        mkdir tarballcache
    fi
    if [ ! -f tarballcache/$MYSQL_BASE ]; then
        wget "${DBTARBALL}"  -O - | tee tarballcache/$MYSQL_BASE  | tar -zxf -
    else
        tar -zxf tarballcache/$MYSQL_BASE
    fi
    export MYSQL_BASE=${MYSQL_BASE%.tar*}
    export PATH="${HOME}/$MYSQL_BASE/bin:$PATH"
    export PIDFILE=${HOME}/mysqld.pid
    export ERRORLOG=${HOME}/mysqld.err
    cd "${HOME}/${MYSQL_BASE}"
    ARGS="--no-defaults --basedir=${HOME}/${MYSQL_BASE} --datadir=${HOME}/${MYSQL_BASE}/data --log-error=${ERRORLOG}"
    ./scripts/mysql_install_db ${ARGS}
    ./bin/mysqld_safe ${ARGS} --ledir=${HOME}/${MYSQL_BASE}/bin --pid-file=${PIDFILE} --socket=/tmp/mysql.sock &
    sleep 5;
    while [ ! -S /tmp/mysql.sock ] && [ -f ${PIDFILE} ]; do sleep 1 ; done
    popd

    echo -e "[client]\nsocket = /tmp/mysql.sock\nuser = root" > "${HOME}"/.my.cnf
    cp .travis/docker.json pymysql/tests/databases.json
elif [ ! -z "${DB}" ]; then
    # disable existing database server in case of accidential connection
    sudo service mysql stop

    docker pull mysql:${DB}
    docker run -it --name=mysqld -d -e MYSQL_ALLOW_EMPTY_PASSWORD=yes -p 3306:3306 mysql:${DB}
    sleep 10

    while :
    do
        sleep 5
        mysql -uroot -h 127.0.0.1 -P 3306 -e 'select version()'
        if [ $? = 0 ]; then
            break
        fi
        echo "server logs"
        docker logs --tail 5 mysqld
    done

    echo -e "[client]\nhost = 127.0.0.1\nuser = root" > "${HOME}"/.my.cnf

    cp .travis/docker.json pymysql/tests/databases.json
else
    cp .travis/database.json pymysql/tests/databases.json
fi

cat ~/.my.cnf

mysql -e 'select VERSION()'
mysql -e 'create database test1 DEFAULT CHARACTER SET utf8 DEFAULT COLLATE utf8_general_ci;'
mysql -e 'create database test2 DEFAULT CHARACTER SET utf8 DEFAULT COLLATE utf8_general_ci;'

mysql -u root -e "create user test2           identified by 'some password'; grant all on test2.* to test2;"
mysql -u root -e "create user test2@localhost identified by 'some password'; grant all on test2.* to test2@localhost;"

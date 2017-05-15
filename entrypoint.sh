#!/bin/bash
# Inspired by https://github.com/docker-library/mysql
set -eo pipefail
shopt -s nullglob

# Check if database is initialized
if [ ! -d "/mysql/data/mysql" ]; then

    echo 'Initializing database'
    cd /mysql
    scripts/mysql_install_db --user=kuborgh
    echo 'Database initialized'

    rootCreate=
    # default root to listen for connections from anywhere
    if [ ! -z "$MYSQL_ROOT_HOST" -a "$MYSQL_ROOT_HOST" != 'localhost' ]; then
        # no, we don't care if read finds a terminating character in this heredoc
        # https://unix.stackexchange.com/questions/265149/why-is-set-o-errexit-breaking-this-read-heredoc-expression/265151#265151
        read -r -d '' rootCreate <<-EOSQL || true
            CREATE USER 'root'@'${MYSQL_ROOT_HOST}' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}' ;
            GRANT ALL ON *.* TO 'root'@'${MYSQL_ROOT_HOST}' WITH GRANT OPTION ;
EOSQL
    fi

    # Start daemon for init purpose
    echo 'Starting server to setup users'
    "bin/mysqld" --skip-networking --basedir=/mysql --datadir=/mysql/data --user=kuborgh &
    pid="$!"
    mysql=( bin/mysql -uroot )

    # Waiting for daemon to come up
    for i in {30..0}; do
        if echo 'SELECT 1' | "${mysql[@]}" &> /dev/null; then
            break
        fi
        echo '.'
        sleep 1
    done
    if [ "$i" = 0 ]; then
        echo >&2 'MySQL init process failed.'
        exit 1
    fi
    echo 'Startup done'

    echo 'Remove test data'
    ${mysql[@]} <<-EOSQL
                -- What's done in this file shouldn't be replicated
                --  or products like mysql-fabric won't work
                SET @@SESSION.SQL_LOG_BIN=0;

                DELETE FROM mysql.user WHERE user NOT IN ('mysql.sys', 'mysqlxsys', 'root') OR host NOT IN ('localhost') ;
                SET PASSWORD FOR 'root'@'localhost'=PASSWORD('${MYSQL_ROOT_PASSWORD}') ;
                GRANT ALL ON *.* TO 'root'@'localhost' WITH GRANT OPTION ;
                ${rootCreate}
                DROP DATABASE IF EXISTS test ;
                FLUSH PRIVILEGES ;
EOSQL
    echo 'Test data removed'
    mysql+=( -p"${MYSQL_ROOT_PASSWORD}" )

    # Create database
    if [ "$MYSQL_DATABASE" ]; then
        echo "CREATE DATABASE IF NOT EXISTS \`$MYSQL_DATABASE\` ;" | "${mysql[@]}"
        mysql+=( "$MYSQL_DATABASE" )
        echo "Create database $MYSQL_DATABASE"
    fi

    # Create user
    if [ "$MYSQL_USER" -a "$MYSQL_PASSWORD" ]; then
        echo "CREATE USER '$MYSQL_USER'@'%' IDENTIFIED BY '$MYSQL_PASSWORD' ;" | "${mysql[@]}"

        if [ "$MYSQL_DATABASE" ]; then
            echo "GRANT ALL ON \`$MYSQL_DATABASE\`.* TO '$MYSQL_USER'@'%' ;" | "${mysql[@]}"
        fi

        echo 'FLUSH PRIVILEGES ;' | "${mysql[@]}"
        echo "Create user $MYSQL_USER"
    fi

    # Init done - kill daemon
    echo "Try to kill $pid"
    if ! kill -s TERM "$pid" || ! wait "$pid"; then
        echo 'killed'
        #echo >&2 'MySQL init process failed.'
        #exit 1
    fi
    echo 'end'
fi

exec "$@"

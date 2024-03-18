#!/bin/bash

# MySQL �����̳� ����
docker-compose up -d

if [ $? -ne 0 ]; then
    echo "Docker compose failed to start."
    exit 1
fi

sleep 10 # �����̳ʰ� �ö���� �ð� ��ٸ�

# �����̳� ���� Ȯ��
CONTAINER_CHECK=$(docker-compose ps | grep 'Up')
if [ -z "$CONTAINER_CHECK" ]; then
    echo "One or more containers failed to start."
    exit 1
else
    echo "All containers are up and running."
fi

# MySQL ���� �غ�� ������ ��ٸ�
wait_for_mysql() {
    container_name=$1
    for i in {1..30}; do
        if docker exec $container_name mysqladmin ping -h "localhost" --silent; then
            echo "$container_name is up and running."
            return 0
        else
            echo "Waiting for $container_name to be ready..."
            sleep 1
        fi
    done
    echo "Failed to connect to $container_name after several attempts."
    return 1
}

# MySQL ���� �غ� ���� Ȯ��
wait_for_mysql "mysql1" && \
wait_for_mysql "mysql2" && \
wait_for_mysql "mysql3"

# MySQL �ν��Ͻ� ����
docker exec -it mysql1 mysqlsh --user root --password=1234 --execute "dba.configureInstance('root@localhost:3306');" && \
docker exec -it mysql1 mysqlsh --user root --password=1234 --execute "dba.configureInstance('root@mysql2:3306');" && \
docker exec -it mysql1 mysqlsh --user root --password=1234 --execute "dba.configureInstance('root@mysql3:3306');"

# Ŭ������ ����
if ! docker exec -it mysql1 mysqlsh --user root --password=1234 --execute "var cluster = dba.createCluster('testCluster');"
then
    echo "Failed to create cluster."
    exit 1
fi

wait_for_mysql "mysql2" && \
wait_for_mysql "mysql3"

# ù ��° �߰� �ν��Ͻ��� Ŭ�����Ϳ� �߰� �� ��׶��忡�� ����
docker exec mysql1 mysqlsh --user root --password=1234 --execute "var cluster = dba.getCluster(); cluster.addInstance('root@localhost:3307', {recoveryMethod: 'auto'});"

# addInstance ���� �߿� mysql2 �����
docker restart mysql2 &

# �� ��ɾ ���ÿ� ����� �� �ֵ��� ��� ���
sleep 5

# �� ��° �߰� �ν��Ͻ��� Ŭ�����Ϳ� �߰� �� ��׶��忡�� ����
docker exec mysql1 mysqlsh --user root --password=1234 --execute "var cluster = dba.getCluster(); cluster.addInstance('root@localhost:3308', {recoveryMethod: 'auto'});" 

# addInstance ���� �߿� mysql3 �����
docker restart mysql3 &

# �� ��ɾ ���ÿ� ����� �� �ֵ��� ��� ���
sleep 5

# Ŭ������ �˻�
if ! docker exec -it mysql1 mysqlsh --user root --password=1234 --execute "var cluster = dba.getCluster(); cluster.rescan();"
then
    echo "Failed to rescan the cluster."
    exit 1
fi

echo "MySQL cluster setup completed successfully."


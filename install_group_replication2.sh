#!/bin/bash

# MySQL 컨테이너 시작
docker-compose up -d

if [ $? -ne 0 ]; then
    echo "Docker compose failed to start."
    exit 1
fi

sleep 10 # 컨테이너가 올라오는 시간 기다림

# 컨테이너 상태 확인
CONTAINER_CHECK=$(docker-compose ps | grep 'Up')
if [ -z "$CONTAINER_CHECK" ]; then
    echo "One or more containers failed to start."
    exit 1
else
    echo "All containers are up and running."
fi

# MySQL 서비스 준비될 때까지 기다림
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

# MySQL 서버 준비 상태 확인
wait_for_mysql "mysql1" && \
wait_for_mysql "mysql2" && \
wait_for_mysql "mysql3"

# MySQL 인스턴스 구성
docker exec -it mysql1 mysqlsh --user root --password=1234 --execute "dba.configureInstance('root@localhost:3306');" && \
docker exec -it mysql1 mysqlsh --user root --password=1234 --execute "dba.configureInstance('root@mysql2:3306');" && \
docker exec -it mysql1 mysqlsh --user root --password=1234 --execute "dba.configureInstance('root@mysql3:3306');"

# 클러스터 생성
if ! docker exec -it mysql1 mysqlsh --user root --password=1234 --execute "var cluster = dba.createCluster('testCluster');"
then
    echo "Failed to create cluster."
    exit 1
fi

wait_for_mysql "mysql2" && \
wait_for_mysql "mysql3"

# 첫 번째 추가 인스턴스를 클러스터에 추가 및 백그라운드에서 실행
docker exec mysql1 mysqlsh --user root --password=1234 --execute "var cluster = dba.getCluster(); cluster.addInstance('root@localhost:3307', {recoveryMethod: 'auto'});"

# addInstance 실행 중에 mysql2 재시작
docker restart mysql2 &

# 두 명령어가 동시에 실행될 수 있도록 잠시 대기
sleep 5

# 두 번째 추가 인스턴스를 클러스터에 추가 및 백그라운드에서 실행
docker exec mysql1 mysqlsh --user root --password=1234 --execute "var cluster = dba.getCluster(); cluster.addInstance('root@localhost:3308', {recoveryMethod: 'auto'});" 

# addInstance 실행 중에 mysql3 재시작
docker restart mysql3 &

# 두 명령어가 동시에 실행될 수 있도록 잠시 대기
sleep 5

# 클러스터 검사
if ! docker exec -it mysql1 mysqlsh --user root --password=1234 --execute "var cluster = dba.getCluster(); cluster.rescan();"
then
    echo "Failed to rescan the cluster."
    exit 1
fi

echo "MySQL cluster setup completed successfully."


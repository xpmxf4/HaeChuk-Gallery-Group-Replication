#!/bin/bash

# MySQL 컨테이너 실행 및 상태 확인
docker-compose up -d
CONTAINER_CHECK=$(docker-compose ps | grep 'Up')

# 인스턴스 구성
for i in {1..3}; do
  docker exec -it mysql1 mysqlsh --user root --password=$MYSQL_ROOT_PASSWORD \
    --execute "dba.configureInstance('root@mysql$i:3306');"
done

# 클러스터 생성 및 인스턴스 추가
docker exec -it mysql1 mysqlsh --user root --password=$MYSQL_ROOT_PASSWORD \
  --execute "var cluster = dba.createCluster('testCluster');"

for i in {2..3}; do
  docker exec -it mysql1 mysqlsh --user root --password=$MYSQL_ROOT_PASSWORD \
    --execute "dba.getCluster().addInstance('root@mysql$i:3306', {recoveryMethod: 'auto'});"
done

# 클러스터 상태 검사 및 출력
docker exec -it mysql1 mysqlsh --user root --password=$MYSQL_ROOT_PASSWORD \
  --execute "var cluster = dba.getCluster(); cluster.rescan(); print(JSON.stringify(cluster.status(), null, 2));"

echo "MySQL cluster setup completed successfully."
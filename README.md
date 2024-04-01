# Docker를 이용한 MySQL Group Replication 자동 구축

이 프로젝트는 [해축갤 프로젝트](https://github.com/xpmxf4/HaeChuk-Gallery) 의 서브 프로젝트로, DB Replication 을 안드로이드 공기계에 편하게 배포하기 위한 프로젝트입니다.

"Real MySQL 2" 책을 참고하여, Docker를 사용하여 Group Replication을 신속하고 쉽게 설정할 수 있도록 설계되었습니다.

## 사전 준비사항

- Docker 및 Docker Compose 설치
- 프로젝트 파일 준비 (`docker-compose.yml`, `Dockerfile`, `docker-entrypoint.sh`, `install_group_replication.sh`)

## 설정 과정

### 1. Docker 이미지 빌드

- 필요한 이미지는 총 2 가지 입니다.
  ### **MySQL Server + MySQL Shell**
    - `docker-entrypoint.sh` 스크립트를 사용하여 MySQL 8.0.36 기반의 이미지를 준비합니다.
  이 스크립트는 MySQL 설정과 초기 실행을 위한 로직을 포함합니다.

    - Dockerfile을 통해 Docker(MySQL+MySQL Shell) 이미지를 빌드합니다.

    ```bash
    docker build -t my-custom-mysql:8.0.36 .
    ```

    ### MySQL Router

    - MySQL Router 이미지를 다운 받습니다.

    ```bash
    docker pull container-registry.oracle.com/mysql/community-router:tag
    ```

### 2. MySQL Group Replication 설치 및 실행

- ```bash
  install_group_replication.sh
  ```

   스크립트를 실행하여 Group Replication 구성을 완료합니다. 이 스크립트는 다음 작업을 수행합니다:

  1. Docker 컨테이너 시작
  2. MySQL 서버 준비 대기
  3. MySQL 서버 실행
  4. MySQL Router 실행
  5. MySQL 인스턴스 구성 (`dba.configureInstance`)
  6. 클러스터 생성 (`dba.createCluster`) 및 인스턴스 추가 (`cluster.addInstance`)
  7. 클러스터 상태 검사 및 출력


## Group Replication 설정

- 이 프로젝트는 싱글 프라이머리 모드로 세팅됩니다.

- 기본적으로 1개의 프라이머리 노드와 2개의 세컨더리 노드로 구성됩니다.

- 노드를 추가하고자 할 경우, 
  
  `docker-compose.yml` 파일에 다음과 같이 추가합니다:

  ```yaml
  services:
    mysql4:
      image: my-custom-mysql:8.0.36
      environment:
        MYSQL_ROOT_PASSWORD: root_password
        # 추가 환경 변수 설정
      command:
        - --server-id=4 # 다른 서버와 무조건 다르게 해야한다.
        - --log-bin=mysql-bin-3.log
        - --enforce-gtid-consistency=ON
        - --gtid-mode=ON
        - --transaction-write-set-extraction=XXHASH64
        - --binlog-checksum=NONE
        - --plugin-load=group_replication.so
      ports:
        - "3310:3306" # Port 는 자유
      # 기타 필요한 설정 추가
  ```

## 주의사항

- 이 프로젝트는 교육 및 테스트 목적으로 사용될 수 있습니다. 실제 프로덕션 환경에서 사용하기 전에는 보안 설정과 성능 최적화를 고려해야 합니다.
- Group Replication 설정 시 네트워크 환경과 인스턴스 설정을 정확히 맞춰야 합니다. 설정 오류는 클러스터의 정상 작동을 방해할 수 있습니다.

이 문서를 통해 Docker 환경에서 MySQL Group Replication을 쉽게 설정하고 실험해 볼 수 있습니다.

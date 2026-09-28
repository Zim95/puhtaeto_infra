# Postgres Setup
Currently there is no support for High Availability Postgres Cluster.
We currently only support a single Postgres instance with a K8s service.

# Prerequisites
1. Docker installed.
2. Kubernetes and kubectl setup.

# How to setup?
1. Clone this repository:
    ```bash
    $ git clone https://github.com/Zim95/postgres_ha
    ```

2. Once done, create an `env.mk` file with the following details:
    ```Makefile
    NAMESPACE=<namespace>

    POSTGRES_PASSWORD=<password>
    POSTGRES_USER=<username>
    POSTGRES_DB=<dbname>
    POSTGRES_TEST_DB=<testdbname>
    ```

3. Make all the scripts executable:
    ```bash
    $ chmod +x ./scripts/**/*
    ```

4. Setup postgres pod and service:
    ```bash
    $ make dev_pg_single_setup
    ```

5. Teardown postgres pod and service:
    ```bash
    $ make dev_pg_single_teardown
    ```

> Note: The setup exposes the Postgres instance as the K8s service `browseterm-pg-service:5432` (use this as `POSTGRES_HOST` for other services).

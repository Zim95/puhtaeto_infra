include env.mk

dev_setup:
	./scripts/development/etcd/etcd.setup.sh $(NAMESPACE)
	./scripts/development/postgres/postgres.setup.sh $(NAMESPACE)

dev_teardown:
	./scripts/development/etcd/etcd.teardown.sh $(NAMESPACE)
	./scripts/development/postgres/postgres.teardown.sh $(NAMESPACE)

dev_pg_single_setup:
	./scripts/development/pg_single/pg_single.setup.sh "$(NAMESPACE)" "$(POSTGRES_USER)" "$(POSTGRES_PASSWORD)" "$(POSTGRES_DB)" "$(POSTGRES_TEST_DB)" "$(EXPECTED_KUBE_CONTEXT)"

dev_pg_single_teardown:
	./scripts/development/pg_single/pg_single.teardown.sh $(NAMESPACE)

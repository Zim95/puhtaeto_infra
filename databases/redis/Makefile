include env.mk

dev_redis_single_setup:
	./scripts/development/redis_single/redis_single.setup.sh "$(NAMESPACE)" "$(REDIS_USER)" "$(REDIS_PASSWORD)" "$(EXPECTED_KUBE_CONTEXT)"

dev_redis_single_teardown:
	./scripts/development/redis_single/redis_single.teardown.sh $(NAMESPACE)

# Help target
help:
	@echo "Available targets:"
	@echo "Redis HA targets:"
	@echo "  dev_redis_single_setup     - Setup Redis single instance"
	@echo "  dev_redis_single_teardown  - Teardown Redis single instance"
	@echo ""

.PHONY: deploy
deploy:
	@./hack/deploy.sh
	@echo
	@echo "The stack is now ready!"
	@echo "Navigate to http://cloudevents-player.crawler-system.127.0.0.1.sslip.io to start sending CloudEvents"
	@echo
	@echo "For example, try sending and Event with:"
	@echo "Type: io.podgateway.client.pending"
	@echo \"Message: { "gateway_name": "foo" }\"
	@echo
	@echo "Then, as soon you'll see a 'io.podgateway.client.scheduling.done' Event, you can retrieve Crawler Pod details from the Event Data"
	@echo


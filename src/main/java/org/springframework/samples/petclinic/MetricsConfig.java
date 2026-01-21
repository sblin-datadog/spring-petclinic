package org.springframework.samples.petclinic;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import com.timgroup.statsd.NonBlockingStatsDClientBuilder;
import com.timgroup.statsd.StatsDClient;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

@Configuration
public class MetricsConfig {

	private static final Logger logger = LogManager.getLogger(MetricsConfig.class);

	@Bean
	public StatsDClient statsDClient() {

		StatsDClient statsd = new NonBlockingStatsDClientBuilder().prefix("petclinic")
			.hostname(System.getenv().getOrDefault("DD_AGENT_HOST", "localhost"))
			.port(8125)
			.errorHandler(e -> {
				// Log and ignore all errors
				logger.error("Error sending statsd metric: " + e.getMessage());
			})
			.build();

		return statsd;
	}

}

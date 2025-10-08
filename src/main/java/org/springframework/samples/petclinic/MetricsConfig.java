package org.springframework.samples.petclinic;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import com.timgroup.statsd.NonBlockingStatsDClientBuilder;
import com.timgroup.statsd.StatsDClient;

@Configuration
public class MetricsConfig {

	@Bean
	public StatsDClient statsDClient() {

		StatsDClient statsd = new NonBlockingStatsDClientBuilder().prefix("petclinic")
			.hostname(System.getenv().getOrDefault("DD_AGENT_HOST", "localhost"))
			.port(8125)
			.build();

		return statsd;
	}

}

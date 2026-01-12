package org.springframework.samples.petclinic.springservice;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.reactive.function.client.WebClient.Builder;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.core.publisher.Mono;
import org.springframework.ui.Model;

@Controller
class SpringServiceController {

	private static final Logger logger = LogManager.getLogger(SpringServiceController.class);

	private final WebClient webClient;

	private final String remoteUrl;

	public SpringServiceController(WebClient.Builder builder, @Value("${springservice.remote-url}") String remoteUrl) {
		this.webClient = builder.build();
		this.remoteUrl = remoteUrl;
	}

	@GetMapping("/springservice")
	public String callSpringService(Model model) {
		logger.info("Calling remote spring service at: {}", remoteUrl);

		String message = webClient.get().uri(remoteUrl).retrieve().bodyToMono(String.class).block();
		logger.info("Received response from spring service: {}", message);
		model.addAttribute("msg", message);

		return "springservice";
	}

}

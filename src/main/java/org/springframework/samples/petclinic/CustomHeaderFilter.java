package org.springframework.samples.petclinic;

import java.io.IOException;
import java.time.Instant;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;
import com.timgroup.statsd.StatsDClient;

@Component
public class CustomHeaderFilter extends OncePerRequestFilter {

	private final StatsDClient statsDClient;

	public CustomHeaderFilter(StatsDClient statsDClient) {
		this.statsDClient = statsDClient;
	}

	@Override
	protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
			throws ServletException, IOException {

		int[] httpCodes = { 200, 201, 204, 301, 302, 400, 401, 403, 404, 500, 502, 503 };
		int randomCode = httpCodes[new java.util.Random().nextInt(httpCodes.length)];
		response.addHeader("x-custom-random-error", String.valueOf(randomCode));
		response.addHeader("x-custom-timestamp", Instant.now().toString());
		filterChain.doFilter(request, response);

		// Send histogram metrics to Datadog
		this.statsDClient.histogram("custom.header.random.error.code", randomCode,
				new String[] { "customErrorCode:" + randomCode });

		System.out.println("Added custom 123ddrt/test/url/234/devices/ajkdjked678yjdnkf89879/test3");
		System.out.println("code:" + randomCode);
	}

}

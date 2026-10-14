/*
 * Copyright 2012-2025 the original author or authors.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package org.springframework.samples.petclinic.system;

import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;
import java.util.List;

import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;

/**
 * Controller used to showcase Datadog App &amp; API Protection detections. The
 * {@code /vuln/*} endpoints are deliberately unsafe and exist only to generate security
 * signals for demos. Do not expose them in production.
 */
@Controller
class SecurityDemoController {

	private static final Logger logger = LogManager.getLogger(SecurityDemoController.class);

	@PersistenceContext
	private EntityManager entityManager;

	@GetMapping("/security-demo")
	public String securityDemo() {
		return "security-demo";
	}

	/**
	 * Weak hashing (MD5) sink. IAST flags WEAK_HASH as soon as this runs, no attack
	 * payload required.
	 */
	@GetMapping("/vuln/hash")
	public String weakHash(@RequestParam(defaultValue = "demo") String input, Model model) {
		logger.info("Security demo: hashing input with MD5");
		try {
			MessageDigest md5 = MessageDigest.getInstance("MD5");
			byte[] digest = md5.digest(input.getBytes());
			model.addAttribute("result", "MD5(" + input + ") = " + HexFormat.of().formatHex(digest));
		}
		catch (NoSuchAlgorithmException ex) {
			model.addAttribute("result", "MD5 not available: " + ex.getMessage());
		}
		return "security-demo";
	}

	/**
	 * SQL injection sink: a native query built by string concatenation from user input.
	 * IAST flags SQL_INJECTION when exercised with a crafted value.
	 */
	@GetMapping("/vuln/sql")
	public String sqlInjection(@RequestParam(defaultValue = "Franklin") String lastName, Model model) {
		logger.info("Security demo: running raw SQL query for lastName={}", lastName);
		String sql = "SELECT first_name, last_name FROM owners WHERE last_name = '" + lastName + "'";
		List<?> rows = this.entityManager.createNativeQuery(sql).getResultList();
		model.addAttribute("result", "Query returned " + rows.size() + " row(s) for: " + sql);
		return "security-demo";
	}

}

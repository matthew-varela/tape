package com.tape.api;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.ConfigurationPropertiesScan;

@SpringBootApplication
@ConfigurationPropertiesScan
public class TapeApiApplication {

    public static void main(String[] args) {
        SpringApplication.run(TapeApiApplication.class, args);
    }
}

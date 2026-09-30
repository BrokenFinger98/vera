package com.brokenfinger.vera

import org.springframework.boot.autoconfigure.SpringBootApplication
import org.springframework.boot.runApplication
import org.springframework.modulith.Modulithic

@SpringBootApplication @Modulithic(systemName = "Vera") class VeraApplication

fun main(args: Array<String>) {
    runApplication<VeraApplication>(*args)
}

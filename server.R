library(shiny)
library(tidyverse, warn.conflicts = FALSE)
library(ggrepel)

source('functions.R')

server <- function(input, output) {

    output$slider <- renderUI({
        sliderInput('n1', label = 'n1', value = min(max(1, ceiling(input$sampleSize1 / 3)), input$sampleSize1 - 1) , min = 1, max = input$sampleSize1 - 1, step = 1)
    })

    n1 <- reactive({
        if (is.null(input$n1)) 1 else input$n1
    })

    output$expectedPowerPlot <- renderPlot({

        crit      <- qnorm(.975)
        prior     <- Normal(input$priorMean1, input$priorSd1)
        cprior    <- condition(prior, input$mrv1)
        ep        <- EP(prior, input$sampleSize1, crit, input$mrv1)
        pow       <- power(input$mrv1, input$sampleSize1, crit)
        pow2      <- power(input$priorMean1, input$sampleSize1, crit)
        tbl_power <- tibble(
            Delta  = seq(-.25, 1, by = .001),
            cprior = pdf(cprior, Delta),
            power  = power(Delta, input$sampleSize1, crit)
        )
        tbl_labels <- tibble(
            Delta = c(
                tbl_power$Delta[which.min(abs(tbl_power$power - pow))],
                tbl_power$Delta[which.min(abs(tbl_power$power - pow2))],
                tbl_power$Delta[which.min(abs(tbl_power$power - ep))]
            ),
            power = c(pow, pow2, ep),
            label = c(
                sprintf('power, MRV: %5.1f%%', 100*pow),
                sprintf('power, prior mean: %5.1f%%', 100*pow2),
                sprintf('expected power: %5.1f%%', 100*ep)
            )
        )

        p1 <- ggplot(tbl_power) +
            aes(Delta, power) +
            geom_ribbon(aes(ymin = 0, ymax = 1), fill = 'red', alpha = .1, data = tbl_power %>% filter(Delta < 0)) +
            geom_ribbon(aes(ymin = 0, ymax = 1), fill = 'green', alpha = .1, data = tbl_power %>% filter(Delta >= input$mrv1)) +
            geom_line(aes(alpha = cprior), size = 1.25) +
            geom_point(size = 2, data = tbl_labels) +
            geom_text_repel(aes(label = label), min.segment.length = 0,
                            force = 2, segment.alpha = .5, nudge_x = .25, nudge_y = -.1,
                            data = tbl_labels
            ) +
            coord_cartesian(xlim = range(tbl_power$Delta), ylim = c(0, 1), expand = FALSE) +
            theme_bw() +
            theme(
                legend.position = 'none'
            )

        tbl_cpower <- tibble(
                estimate = seq(-.25, 1, by = .001),
                `CP, prior mean` = map_dbl(
                    sqrt(n1())*estimate,
                    ~CP(., n1(), input$sampleSize1, crit, input$priorMean1)
                ),
                `CP, MRV` = map_dbl(
                    sqrt(n1())*estimate,
                    ~CP(., n1(), input$sampleSize1, crit, input$mrv1)
                ),
                OCP = map_dbl(
                    sqrt(n1())*estimate,
                    ~OCP(., n1(), input$sampleSize1, crit, input$mrv1)
                ),
                CEP = map_dbl(
                    sqrt(n1())*estimate,
                    ~CEP(prior, ., n1(), input$sampleSize1, crit, input$mrv1)
                )
            ) %>%
            pivot_longer(-estimate, names_to = 'type', values_to = 'conditional power')

        p2 <- ggplot(tbl_cpower) +
            aes(estimate, `conditional power`) +
            geom_line(aes(color = type)) +
            coord_cartesian(xlim = range(tbl_cpower$estimate), ylim = c(0, 1), expand = FALSE) +
            theme_bw() +
            theme(
                legend.position = 'none'
            )

        tbl_sample <- tibble(
                sample = rnorm(10^3, sqrt(input$sampleSize1)*input$sampleDelta, 1),
                `CP, prior mean` = map_dbl(
                    sample,
                    ~CP(., n1(), input$sampleSize1, crit, input$priorMean1)
                ),
                `CP, MRV` = map_dbl(
                    sample,
                    ~CP(., n1(), input$sampleSize1, crit, input$mrv1)
                ),
                OCP = map_dbl(
                    sample,
                    ~OCP(., n1(), input$sampleSize1, crit, input$mrv1)
                ),
                CEP = map_dbl(
                    sample,
                    ~CEP(prior, ., n1(), input$sampleSize1, crit, input$mrv1)
                )
            ) %>%
            pivot_longer(-sample, names_to = 'type', values_to = 'conditional power')

        p3 <- ggplot(tbl_sample) +
            aes(`conditional power`) +
            geom_histogram(aes(fill = type), bins = 21) +
            facet_wrap(~type) +
            theme_bw() +
            theme(
                legend.position = 'top'
            )


        tbl_priors <- tibble(
                Delta               = tbl_power$Delta,
                prior               = pdf(prior, Delta),
                `conditional prior` = pdf(cprior, Delta)
            ) %>%
            mutate(
                `conditional prior` = {
                    res <- `conditional prior`
                    res[which.min(abs(Delta - input$mrv1))] <- NA_real_
                    res
                }
            ) %>%
            pivot_longer(-Delta, names_to = 'type', values_to = 'PDF')


        p4 <- ggplot(tbl_priors) +
            aes(Delta, PDF) +
            geom_line(aes(color = type), alpha = .66) +
            theme_bw() +
            theme(
                legend.position = 'top'
            )

        gridExtra::grid.arrange(p1, p2, p4, p3, ncol = 2, nrow = 2)

    })

}

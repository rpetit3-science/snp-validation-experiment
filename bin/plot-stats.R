#! /usr/bin/Rscript
# Plot the true positive rate, false positive rate and true negative rate for
# each distance and coverage.
# plot-stats.R [INPUT]
# ./plot-stats.R validation_stats_sorted.txt
library(ggplot2)
library(reshape2)

facet_labels <- function(variable, value) {
    return(paste(format(c(value),big.mark=",", trim=TRUE), "Variants", sep=" "))
}

# Get arguements
args<-commandArgs(TRUE)
file <- args[1]
file_without_ext <- gsub(".txt$", "", file)
results <- read.table(file, header=TRUE, sep = "\t")

melt_results <- melt(
    results,
    id.vars=c("variants", "coverage"),
    measure.vars=c("TPR", "FPR", "FNR", "TNR")
)

melt_results$variantsLab <- factor(
    facet_labels('variable',melt_results$variants),
    levels = facet_labels('variable', sort(unique(melt_results$variants)))
)

output <- paste(file_without_ext, ".pdf", sep="")
pdf(output, onefile=TRUE, width=12, height=8)

p <- ggplot(melt_results, aes(x=coverage, y=value, color=variable)) +
        geom_line(size=1) +
        labs(title=paste(
            "Variant calling true positive (sensitivy), false positive,",
            "false negative,\n and true negative (specificity) rates",
            "for 12 genetic distances and 1-50x coverage.",
            sep=" ")
        ) +
        xlab("Coverage") +
        ylab("") +
        facet_wrap(~ variantsLab) +
        theme_bw(base_size = 18) +
        theme(
            legend.text=element_text(size=16),
            legend.title = element_blank(),
            plot.title=element_text(size=16)
        )
print(p)
dev.off()

TOP_DIR := $(shell pwd)
THIRD_PARTY := $(TOP_DIR)/src/third-party
THIRD_PARTY_PYTHON := $(TOP_DIR)/src/third-party/python
THIRD_PARTY_BIN := $(TOP_DIR)/bin/third-party



.PHONY: all test clean ${RUNS}
all: mkdirs programs run_simulation;

mkdirs: ;
	mkdir -p simulation
	mkdir -p $(THIRD_PARTY)
	mkdir -p $(THIRD_PARTY_BIN)

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
# Clean up everything.                                                        #
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
clean: ;
	rm -rf $(THIRD_PARTY)
	rm -rf $(THIRD_PARTY_BIN)

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
# Build all the programs required to run the simulations.                     #
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
programs: art call_variants;

art: ;
	wget -O $(THIRD_PARTY)/art.tar.gz http://www.niehs.nih.gov/research/resources/assets/docs/artbinchocolatecherrycake031915linux64tgz.tgz
	tar -C $(THIRD_PARTY) -xzvf $(THIRD_PARTY)/art.tar.gz && mv $(THIRD_PARTY)/art_bin_ChocolateCherryCake $(THIRD_PARTY)/art
	ln -s $(THIRD_PARTY)/art/art_illumina $(THIRD_PARTY_BIN)/art_illumina

call_variants: ;
	git clone https://github.com/rpetit3-science/call_variants.git $(THIRD_PARTY)/call_variants
	make -C $(THIRD_PARTY)/call_variants
	make -C $(THIRD_PARTY)/call_variants test
	ln -s $(THIRD_PARTY)/call_variants/bin/call_variants $(THIRD_PARTY_BIN)/call_variants

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
# Run simulations.          .......................................           #
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
REFERENCE := n315
REFERENCE_FASTA := $(TOP_DIR)/data/n315.fasta
REFERENCE_GENBANK := $(TOP_DIR)/data/n315.gb
RANDOM_SEED := 123456
TOTAL_VARIANTS := 100 500 1000 5000 10000 15000 20000 30000 45000 60000 75000 100000
COVERAGE := 1 5 10 15 20 25 30 35 40 45 50
RUNS := $(foreach i,$(TOTAL_VARIANTS),$(foreach j,$(COVERAGE),run-$i-$j))
variants = $(firstword $(subst -, ,$*))
coverage = $(lastword $(subst -, ,$*))
run_simulation: ${RUNS} gather_stats;

${RUNS}: run-%: ;
	@echo Running simulation with $(variants) variants at $(coverage)x coverage.
	$(eval OUT_DIR=simulation/$(variants)/$(coverage)x)
	$(eval BASE_PREFIX=simulation/$(variants)/$(coverage)x/$(REFERENCE)_$(variants))
	$(eval BASE_NAME=$(REFERENCE)_$(variants))
	mkdir -p $(OUT_DIR)
	# Create random mutations in the reference
	$(TOP_DIR)/bin/mutate-reference $(REFERENCE_FASTA) $(OUT_DIR) --num_variants $(variants) --seed $(RANDOM_SEED)
	# Simualte Reads using ART
	$(THIRD_PARTY_BIN)/art_illumina -sam -i $(BASE_PREFIX).fasta -l 100 -ss HS20 -f $(coverage) -o $(BASE_PREFIX) -qs 2 -rs $(RANDOM_SEED)
	gzip $(BASE_PREFIX).fq
	# Call variants
	$(THIRD_PARTY_BIN)/call_variants $(BASE_PREFIX).fq.gz $(REFERENCE_FASTA) $(REFERENCE_GENBANK) \
	                                 --output $(OUT_DIR) --read_length 100 -p 1 --log_times \
	                                 --tag $(BASE_NAME)
	# Assess the calls
	$(TOP_DIR)/bin/validate-calls $(BASE_PREFIX).variants $(BASE_PREFIX).variants.vcf.gz > $(BASE_PREFIX).stats
	# Clean Up
	rm $(BASE_PREFIX).aln $(BASE_PREFIX).sam

gather_stats: ;
	sh -c 'find simulation/ -name "*.stats" | head -n 1 | xargs -I {} head -n 1 {} > simulation/validation_stats.txt'
	sh -c 'find simulation/ -name "*.stats" |  xargs -I {} tail -n 1 {} >> simulation/validation_stats.txt'
	sh -c "sed -i 's/^simulation\///; s/x\/n315_[0-9]*.variants//; s/\//\t/; s/^input/variants\tcoverage/' simulation/validation_stats.txt"
	sh -c "sort -nk1,1 -nk2,2 simulation/validation_stats.txt > simulation/validation_stats_sorted.txt"


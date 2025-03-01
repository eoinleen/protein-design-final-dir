#!/bin/bash

# comprehensive_analysis.sh - Script to perform comprehensive analysis of protein binders from ProteinMPNN sc.out

# Default input file
INPUT_FILE="out.sc"
OUTPUT_FILE="top_binders_analysis.txt"

# Function to display usage information
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Performs comprehensive analysis of protein binding scores."
    echo ""
    echo "OPTIONS:"
    echo "  -f, --file FILENAME       Specify input file (default: out.sc)"
    echo "  -o, --output FILENAME     Specify output file (default: top_binders_analysis.txt)"
    echo "  -n, --number NUMBER       Number of top candidates to consider (default: 30)"
    echo "  -h, --help                Show this help message"
    exit 1
}

# Parse command line arguments
TOP_N=30
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--file)
            INPUT_FILE="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -n|--number)
            TOP_N="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Check if file exists
if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: File '$INPUT_FILE' not found."
    exit 1
fi

# Get the header
HEADER=$(grep -m 1 "SCORE:" "$INPUT_FILE" | sed 's/SCORE://')

# Create temporary files for each category
TEMP_DIR=$(mktemp -d)
PLDDT_FILE="${TEMP_DIR}/plddt_binder.txt"
PAE_FILE="${TEMP_DIR}/pae_interaction.txt"
RMSD_FILE="${TEMP_DIR}/binder_aligned_rmsd.txt"
COMBINED_FILE="${TEMP_DIR}/combined.txt"

# Process the file for each category and create the ranking lists
echo "Generating analysis..."

# Extract data rows (skip header)
DATA_ROWS=$(grep "SCORE:" "$INPUT_FILE" | grep -v "binder_aligned_rmsd")

# Get total number of designs
TOTAL_DESIGNS=$(echo "$DATA_ROWS" | wc -l)
if [ "$TOP_N" -gt "$TOTAL_DESIGNS" ]; then
    TOP_N=$TOTAL_DESIGNS
    echo "Note: Only $TOTAL_DESIGNS designs available, using all of them."
fi

# 1. Top for plddt_binder (highest is better)
echo "$DATA_ROWS" | sort -k 6 -n -r > "$PLDDT_FILE"

# 2. Top for pae_interaction (lowest is better)
echo "$DATA_ROWS" | sort -k 4 -n > "$PAE_FILE"

# 3. Top for binder_aligned_rmsd (lowest is better)
echo "$DATA_ROWS" | sort -k 2 -n > "$RMSD_FILE"

# Create lists of designs in each category
PLDDT_DESIGNS=$(head -n "$TOP_N" "$PLDDT_FILE" | awk '{print $NF}')
PAE_DESIGNS=$(head -n "$TOP_N" "$PAE_FILE" | awk '{print $NF}')
RMSD_DESIGNS=$(head -n "$TOP_N" "$RMSD_FILE" | awk '{print $NF}')

# Find designs that appear in all three lists
COMBINED_DESIGNS=$(echo "$PLDDT_DESIGNS $PAE_DESIGNS $RMSD_DESIGNS" | tr ' ' '\n' | sort | uniq -c | grep -v "^ *1 " | awk '{print $2}')

# For each combined design, extract its row
for DESIGN in $COMBINED_DESIGNS; do
    grep "$DESIGN" "$PAE_FILE" >> "$COMBINED_FILE"
done

# Write results to output file
{
    echo "====================================================="
    echo "COMPREHENSIVE PROTEIN BINDER ANALYSIS"
    echo "====================================================="
    echo "Input file: $INPUT_FILE"
    echo "Total designs analyzed: $TOTAL_DESIGNS"
    echo "Top candidates considered per metric: $TOP_N"
    echo "Date of analysis: $(date)"
    echo "====================================================="
    echo ""
    
    echo "====================================================="
    echo "TOP $TOP_N DESIGNS BY PLDDT_BINDER (HIGHER IS BETTER)"
    echo "====================================================="
    echo "SCORE:$HEADER"
    head -n "$TOP_N" "$PLDDT_FILE"
    echo ""
    
    echo "====================================================="
    echo "TOP $TOP_N DESIGNS BY PAE_INTERACTION (LOWER IS BETTER)"
    echo "====================================================="
    echo "SCORE:$HEADER"
    head -n "$TOP_N" "$PAE_FILE"
    echo ""
    
    echo "====================================================="
    echo "TOP $TOP_N DESIGNS BY BINDER_ALIGNED_RMSD (LOWER IS BETTER)"
    echo "====================================================="
    echo "SCORE:$HEADER"
    head -n "$TOP_N" "$RMSD_FILE"
    echo ""
    
    echo "====================================================="
    echo "DESIGNS APPEARING IN ALL THREE TOP $TOP_N LISTS"
    echo "RANKED BY PAE_INTERACTION (LOWER IS BETTER)"
    echo "====================================================="
    
    NUM_COMBINED=$(cat "$COMBINED_FILE" | wc -l)
    if [ "$NUM_COMBINED" -eq 0 ]; then
        echo "No designs found in all three categories."
    else
        echo "SCORE:$HEADER"
        cat "$COMBINED_FILE"
        
        # Extract the best overall design
        BEST_OVERALL=$(head -n 1 "$COMBINED_FILE")
        BEST_DESIGN=$(echo "$BEST_OVERALL" | awk '{print $NF}')
        BEST_PAE=$(echo "$BEST_OVERALL" | awk '{print $4}')
        BEST_PLDDT=$(echo "$BEST_OVERALL" | awk '{print $6}')
        BEST_RMSD=$(echo "$BEST_OVERALL" | awk '{print $2}')
        
        echo ""
        echo "====================================================="
        echo "SUMMARY OF BEST OVERALL DESIGN"
        echo "====================================================="
        echo "Best overall design: $BEST_DESIGN"
        echo "PAE_interaction: $BEST_PAE (lower is better)"
        echo "PLDDT_binder: $BEST_PLDDT (higher is better)"
        echo "Binder_aligned_RMSD: $BEST_RMSD (lower is better)"
    fi
    
} > "$OUTPUT_FILE"

# Clean up temporary files
rm -rf "$TEMP_DIR"

echo "Analysis complete! Results written to $OUTPUT_FILE"
echo "Found $(cat "$COMBINED_FILE" | wc -l) designs that appear in all three top $TOP_N lists."

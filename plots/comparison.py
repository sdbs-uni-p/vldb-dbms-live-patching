import streamlit as st
from typing import List
import os
import base64

SCRIPT_DIR = os.path.dirname(os.path.realpath(__file__))

PAPER_DIRECTORY = os.path.join(SCRIPT_DIR, "paper")
REPRODUCTION_DIRECTORY = os.path.join(SCRIPT_DIR, "reproduction")

def get_files(directory: str) -> List[str]:
    return [f for f in os.listdir(directory) if f.endswith(".pdf")]

paper_plots = get_files(PAPER_DIRECTORY)
repro_plots = get_files(REPRODUCTION_DIRECTORY)

common_plots = list(set(paper_plots) & set(repro_plots))

def display_pdf(file):
    with open(os.path.realpath(file), "rb") as f:
        base64_pdf = base64.b64encode(f.read()).decode('utf-8')
   
    pdf_display = F'<iframe src="data:application/pdf;base64,{base64_pdf}" width="100%" height="auto" type="application/pdf"></iframe>'
    st.markdown(pdf_display, unsafe_allow_html=True)

if len(common_plots) == 0:
    st.write("No plots to compare.")
else:
    left, right = st.columns([1, 1])
    left.write("# Paper plots")
    right.write("# Reproduction plots")
    for f in common_plots:
        st.write(f)
        left, right = st.columns([1, 1])
        with left:
            display_pdf(os.path.join(PAPER_DIRECTORY, f))
        with right:
            display_pdf(os.path.join(REPRODUCTION_DIRECTORY, f))


@echo off
cd /d "%~dp0"
python analyze_phase6b_indval_locked_ratings.py > workspace\phase4a_indval\phase6b_analysis_runlog.txt 2>&1
echo EXITCODE=%ERRORLEVEL%>> workspace\phase4a_indval\phase6b_analysis_runlog.txt

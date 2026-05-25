(WIP)

Performance Metrics on sample data using MLClassifier from CreateML framework:

DecisionTreeClassifier

Parameters
Max Depth: 6
Min Loss Reduction: 0.0
Min Child Weight: 0.0
Random Seed: 42

Performance on Training Data
----------------------------------
Number of examples: 1862
Number of classes: 3
Accuracy: 90.66%

******CONFUSION MATRIX******
----------------------------------
True\Pred Core Deep REM  
Core      657  24   26   
Deep      36   620  14   
REM       54   20   411  

******PRECISION RECALL******
----------------------------------
Clas Precision(%) Recall(%)
Core 87.95           92.93          
Deep 93.37           92.54          
REM  91.13           84.74          


Performance on Validation Data
----------------------------------
Number of examples: 206
Number of classes: 3
Accuracy: 89.81%

******CONFUSION MATRIX******
----------------------------------
True\Pred Core Deep REM  
Core      66   3    2    
Deep      6    76   3    
REM       5    2    43   

******PRECISION RECALL******
----------------------------------
Clas Precision(%) Recall(%)
Core 85.71           92.96          
Deep 93.83           89.41          
REM  89.58           86.00          


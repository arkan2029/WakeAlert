(WIP)

Performance Metrics on sample data using MLClassifier from CreateML framework:

BoostedTreeClassifier

Parameters
Max Depth: 6
Max Iterations: 10
Min Loss Reduction: 0.0
Min Child Weight: 0.0
Random Seed: 42
Step Size: 0.3
Row Subsample: 1.0
Column Subsample: 1.0

Performance on Training Data
----------------------------------
Number of examples: 598983
Number of classes: 3
Accuracy: 60.67%

******CONFUSION MATRIX******
----------------------------------
True\Pred Core   Deep   REM    
Core      194456 6771   96725  
Deep      70746  7095   28713  
REM       32601  0      161876 

******PRECISION RECALL******
----------------------------------
Clas Precision(%) Recall(%)
Core 65.30           65.26          
Deep 51.17           6.66           
REM  56.34           83.24          


Performance on Validation Data
----------------------------------
Number of examples: 66553
Number of classes: 3
Accuracy: 60.70%

******CONFUSION MATRIX******
----------------------------------
True\Pred Core  Deep  REM   
Core      21618 749   10739 
Deep      7857  781   3191  
REM       3620  0     17998 

******PRECISION RECALL******
----------------------------------
Clas Precision(%) Recall(%)
Core 65.32           65.30          
Deep 51.05           6.60           
REM  56.37           83.25            

EVALUATION METRICS:
Number of examples: 166385
Number of classes: 3
Accuracy: 60.68%


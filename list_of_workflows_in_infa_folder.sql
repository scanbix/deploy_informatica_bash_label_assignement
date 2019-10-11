/*Find workflow in the folder*/
SELECT  
t.SUBJECT_AREA || '.' || t.WORKFLOW_NAME
FROM edw_REP_WORKFLOWS t
WHERE t.SUBJECT_AREA = 'SE_C1_BBG_SOR'

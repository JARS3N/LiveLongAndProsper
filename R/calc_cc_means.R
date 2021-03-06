calc_cc_means<-function(tbl,var,inst,db){
T0<-gsub("%var%",var,'SELECT Lot,Inst,sn,`%var%` as var from %tbl% where Inst = "%inst%"')
T1<-gsub("%inst%",inst,gsub("%tbl%",tbl,T0))
T2<-gsub("%T1%",T1,'SELECT Lot,sn,AVG(var) as iavg FROM (%T1%) as T1 group by Lot,sn')
query_string<-gsub("%T2%",T2,'SELECT Lot,AVG(iavg)as avg,STD(iavg) as sd,RIGHT(Lot,2) as yr,substr(Lot,2,3) as day FROM (%T2%) as T2 group by Lot order by yr ASC,day ASC;')
query_sent<-RMySQL::dbSendQuery(db,query_string)
x<-RMySQL::dbFetch(query_sent,n=-1)
RMySQL::dbClearResult(query_sent)
x
}

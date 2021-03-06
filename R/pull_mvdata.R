 pull_mvdata<-function(platform,var){
    db<-adminKraken::con_mysql()
    q<-'SELECT Lot,%var% as var,RIGHT(Lot,2) as yr,SUBSTR(Lot,2,3) as day,substr(LOT,2,1)="E" as exp from mvdata where plat="%plat%" order by yr ASC, day ASC;'
    q_str<-gsub("%plat%",platform,gsub("%var%",var,q))
    send_query<-RMySQL::dbSendQuery(db,q_str)
    fetch_query<-RMySQL::dbFetch(send_query,n=-1)
    RMySQL::dbClearResult(send_query)
    RMySQL::dbDisconnect(db)
    fetch_query$use<-c("Production","Experimental")[as.numeric(factor(fetch_query$exp,levels=c(0,1)))]
   fetch_query$exp<-NULL
   fetch_query<-fetch_query[order(as.numeric(fetch_query$yr),fetch_query$day),]
   fetch_query$Lot<-factor(fetch_query$Lot,levels=unique(fetch_query$Lot))
  fetch_query
  }  

release <- R6::R6Class(
  "release",
public = list(
    Lot = NULL,
    type = NULL,
    number = NULL,
    Inst = NULL,
    wetqc = NULL,
    targets = NULL,
    tbl = NULL,
    sn_means = NULL,
    means = NULL,
    sds = NULL,
    cvs = NULL,
    spot_height = NULL,
    dryqc = NULL,
    specs_here = NULL,
    ctg_means =  NULL,
    kable_markdown = NULL,
    RMD = NULL,
    pull_wetqc = function(x,y,z) {
      str<- "SELECT * FROM xtblx where Lot = 'xlotx' AND Inst = 'xinstx';"
        torep<-c("xtblx", "xlotx", "xinstx")
        reps<-c(x,y,z)
       for(i in seq_along(torep)){
        str<- gsub(torep[i],reps[i],str)
       }
      db <- adminKraken::con_mysql()
      q <- RMySQL::dbSendQuery(db, str)
      fet <- RMySQL::fetch(q)
      RMySQL::dbClearResult(q)
      RMySQL::dbDisconnect(db)
      fet
    },
    get_targets=function(lot){
      my_db<-adminKraken::con_dplyr()
      suppressWarnings( tbl(my_db,"lotview") %>%
                          select(.,Type,Lot=`Lot Number`,ID=`Barcode Matrix ID`) %>%
                          filter(Type==substr(lot,1,1) & Lot==substr(lot,2,6)) %>%
                          select(ID) %>% 
                          left_join(.,tbl(my_db,"barcodematrixview"),by="ID") %>% 
                          select( ID,o2em=O2_A,ksv=O2_B,phem=PH_A,slope=PH_B,intercept=PH_C) %>% 
                          mutate(gain=(phem*slope)+intercept) %>% 
                          collect(.,warnings=FALSE) )
    },
   get_sh= function(lot){
      db<-adminKraken::con_dplyr()
      out<-tbl(db,"xf24spotheight") %>%
        filter(Lot==lot) %>%
        summarize(pHeight=mean(pHeight,na.rm=T),oHeight=mean(oHeight,na.rm=T)) %>% 
        collect()
      rm(db)
      gc()
      out
    },
   get_dqc = function(lot){
     my_db<-adminKraken::con_dplyr()
     q<- my_db %>%
       tbl("dryqcxf24") %>%
       filter(Lot==lot) %>%
       mutate(.,PFO2=O2<O2Threshold & O2 > 3) %>%
       mutate(.,PFPH=pH<pHThreshold & pH > 3) %>%
       mutate(.,Pass= PFO2 * PFPH) %>%
       group_by(.,sn) %>%
       summarise(.,Pass=floor(sum(Pass,na.rm=T)/24)) %>%
       summarise(.,
                 percent_fail=100*(1-(sum(Pass,na.rm=T)/n()))
       ) %>% 
       collect() %>% .$percent_fail %>% 
       round(.,2)
     100-q
   },
   gen_spec_test =function(Z){
     list(
       (function(u) {
         u > Z$LOW_LED && u < Z$pH_LED_high
       }),
       (function(u) {
         u < 30
       }),
       (function(u) {
         j<-Z$gain*c(.9,1.1)
         u>=j[1] && j <=j[2]
       }),
       (function(u) {
         u < 5
       }),
       (function(u) {
         u > Z$LOW_LED && u < Z$O2_LED_high
       }),
       (function(u) {
         u < 30
       }),
       (function(u) {
         j<-Z$ksv*c(.9,1.1)
         u>=j[1] && j <=j[2]
       }),
       (function(u) {
         u < 5
       }),
       (function(u){
         u<0.003
       }),
       (function(u){
         u<0.003
       }),
       (function(u){u >= 80})
     )[1:Z$attr_len] 
   },
   gen_attr=function(x){c(
     "pH.LED.avg",
     'pH.LED.CV',
     'Gain.Avg',
     'Gain.CV',
     'O2.LED.Avg',
     'O2.LED.CV',
     'KSV.Avg',
     'KSV.CV',
     'pH Height',
     'O2 Height',
     'Spot Deposition'
   )[1:x]
     },
   gen_spec_str =
     function(ledlow,
              phledhigh,
              o2ledhigh,
              gain,
              ksv,
              attrlen) {
       c(
         paste0(">= ", ledlow, " & <=", phledhigh),
         "< 30",
         paste0(gain * c(1, .1), collapse = " +/- "),
         "< 5",
         paste0(">= ", ledlow, " & <=", o2ledhigh),
         "< 30",
         paste0(ksv * c(1, .1), collapse = " +/- ") ,
         "< 5",
         "< 0.003",
         "< 0.003",
         ">=80%"
       )[1:attrlen]
     },
   test_specs = function(LED_low,pH_LED_high,O2_LED_high,gain,ksv,attrlen){
     list(
       (function(u) {
         u > LED_low && u < pH_LED_high
       }),
       (function(u) {
         u < 30
       }),
       (function(u) {
         j<-gain*c(.9,1.1)
         u>=j[1] && j <=j[2]
       }),
       (function(u) {
         u < 5
       }),
       (function(u) {
         u > LED_low && u < O2_LED_high
       }),
       (function(u) {
         u < 30
       }),
       (function(u) {
         j<-ksv*c(.9,1.1)
         u>=j[1] && j <=j[2]
       }),
       (function(u) {
         u < 5
       }),
       (function(u){
         u<0.003
       }),
       (function(u){
         u<0.003
       }),
       (function(u){u >= 80})
     )[1:attrlen] 
   },
   get_kable = function(){
    if(is.null(self$kable_markdown)){ 
      self$kable_markdown <-knitr::kable(self$ctg_means,
                  format = "markdown",
                  padding = 0,
                  row.names = F,
                  escape = FALSE,
                  longtable=T,
                  options = list(rows.print = 11)
      )}
     self$kable_markdown
   },
   get_RMD = function(){
     if(is.null(self$RMD)){
       dash<-"---  "  
       blank<-"  "
       end_tick<-"```  " 
       stars<-"****  " 
       codeblock<-"```{}  " 
       sig_section<- c(stars,codeblock,rep(blank,3),end_tick,blank)
       fl<-c(
         dash,
         "title: \"%PLAT% Wet QC Lot Release\"  " ,
         "output: html_document  " ,
         dash,
         "### LOT: %Lot%  ",                                                     
         "### QC instrument: %inst%  ",
         self$get_kable(),
         rep(blank,3),
         "### Approved for Release by:  " ,
         sig_section,
         "### Deviation Approved by:  ",
         sig_section
       )
       plat<- c("W"="XFe96","B"="XFe24","C"="XFp","Q"="XF24")[self$type]
       vars<- c("%Lot%","%inst%","%PLAT%")
       vals<- c(self$Lot,self$Inst,plat)
       for (i in 1:3) {fl<-gsub(vars[i],vals[i],fl)}
       self$RMD<- paste0(fl,collapse="\n")
     }
     self$RMD
   },
    initialize = function(LOT, INST) {
      require(dplyr)
      self$Lot <- LOT
      self$Inst <- INST
      self$type <- substr(self$Lot, 1, 1)
      self$number<- substr(self$Lot,2,6)
      self$tbl<-adminKraken::wetqc_tbl()[[self$type]]
      self$wetqc<-self$pull_wetqc(self$tbl,self$Lot,self$Inst)
      self$targets <- self$get_targets(self$Lot)
      self$targets$LED_LOW <-setNames(c(1000,1000,1000,200),c("W","B","C","Q"))[self$type]
      self$targets$pH_LED_high <-setNames(c(15000,20000,10000,900),c("W","B","C","Q"))[self$type]
      self$targets$O2_LED_high <-setNames(c(15000,17000,3000,900),c("W","B","C","Q"))[self$type]
      self$targets$attr_len <- setNames(c(rep(8,3),11),c("W","B","C","Q"))[self$type]
      self$sn_means <-
        group_by(self$wetqc,sn) %>%
        summarise(
          pH.Led.avg = mean(pH.LED),
          Gain.avg = mean(Gain,na.rm=T),
          O2.Led.avg = mean(O2.LED),
          KSV.avg = mean(KSV,na.rm=T)
        ) %>% select(-sn)
      self$means <- summarise_all(self$sn_means,list(mean),na.rm=T)
      self$sds <- summarise_all(self$sn_means,list(sd),na.rm=T)
      self$cvs <- self$sds / self$means * 100
      if(self$type=="Q"){self$spot_height<-self$get_sh(self$Lot)}
      if(self$type=="Q"){self$dryqc<-self$get_dqc(self$Lot)}
      self$ctg_means<-data.frame(attributes =self$gen_attr(self$targets$attr_len))
      self$ctg_means$Values = c(
        round(self$means$pH.Led.avg,0),
        round(self$cvs$pH.Led.avg,2),
        round(self$means$Gain.avg,2),
        round(self$cvs$Gain.avg,2),
        round(self$means$O2.Led.avg,0),
        round(self$cvs$O2.Led.avg,2),
        round(self$means$KSV.avg,4),
        round(self$cvs$KSV.avg,2),
        if(self$type!="Q"){NULL}else{round(self$spot_height$pHeight,5)},
        if(self$type!="Q"){NULL}else{round(self$spot_height$oHeight,5)},
        if(self$type!="Q"){NULL}else{self$dryqc}
      )[1:self$targets$attr_len]
      self$ctg_means$specifications<-self$gen_spec_str(self$targets$LED_LOW,
                                   self$targets$pH_LED_high,
                                   self$targets$O2_LED_high,
                                   self$targets$gain,
                                   self$targets$ksv,
                                   self$targets$attr_len)
      self$specs_here<-self$test_specs(self$targets$LED_LOW,
                                       self$targets$pH_LED_high,
                                       self$targets$O2_LED_high,
                                       self$targets$gain,
                                       self$targets$ksv,
                                       self$targets$attr_len)
      self$ctg_means$Results<-unlist(Map(function(x, y) { x(y)},
                              x=self$specs_here,
                              y = self$ctg_means$Value))
      self$ctg_means$Results <-
        c("FAIL", "PASS")[as.numeric(factor(self$ctg_means$Results, levels = c(FALSE, TRUE)))]
      self$ctg_means$Results[is.na(self$ctg_means$Results)]<-"???"
      self$ctg_means$Values[is.na(self$ctg_means$Values)]<-"missing"
      
    }   
  )
)

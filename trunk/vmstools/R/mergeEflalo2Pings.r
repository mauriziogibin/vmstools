
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!#
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!#
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!#
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!#
# A 'R' ROUTINE FOR THE COUPLING OF VMS AND LOGBOOKS
# WP4 - Lot2 EU tender VMS/LOGBOOKS COUPLING
# author: Francois Bastardie (DTU- Aqua; fba@aqua.dtu.dk)
# January 2010 
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!#
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!#
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!#
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!#




  
 
##!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!##
##!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!##
##!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!##
##!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!##
##!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!##
##!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!##
##!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!##
##!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!##
##!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!##
##!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!##
##!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!##
##!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!##
##!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!##
##!!!!!!!!!!!!!!!!!!!!!!MERGE LOGBOOKS WITH VMS PER VESSEL!!!!!!!!!!!!!!!!!!!!!!##
##!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!##
##!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!##
##!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!##
##!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!##
##!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!##
##!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!##
##!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!##


#!!!!!!!!!!!!!!!!!!!!!#
#!!!!!!!!!!!!!!!!!!!!!#
mergeEflalo2Pings <-
           function(logbooks, tacsat, general=list(output.path=file.path("C:"),
                     visual.check=TRUE, do.wp3=FALSE, speed="segment", conserve.all=TRUE), ...){

  lstargs <- list(...)

  
  # create required folders for outputs
  cat("if it still doesn't exist, 'results' folder is created in ",general$output.path,"\n")    
  dir.create(general$output.path, showWarnings = TRUE, recursive = TRUE, mode = "0777")

  
 #!!!!!!!!!!!!!!!!!!!!!#
 #!!!!!!!!!!!!!!!!!!!!!#
 # utils--
 collapse.all.columns <- function (obj, columns= seq(ncol(obj)) ){
            eval(parse(text=paste('paste(obj[,', paste(columns,collapse='] ,"#", obj[,'), '],sep=\'\')', sep='')))  }
 uncollapse.column <-  function(obj, column="coll"){
            dd<- strsplit(as.character(obj[,column]),"#") ; nco <- length(dd[[1]]) ; dd<- unlist(dd)
            res <- eval(parse(text=paste('data.frame(',paste('dd[seq(',1:nco,',nrow(obj)*nco,by=nco)]', collapse=','),')')))
            colnames(res) <- paste("col",1:nco,sep='')
            return(res)
            }

  #utils--
  # FUNCTION TO CREATE A SPATIAL GRID
  # 'xx' have a 'SI_LATI' and a 'SI_LONG' columns
  assignPointsToSpatialGrid <- function(xx){

    xx <- xx[,!colnames(xx) %in% c("icessquare","icessquare.vms") ]  # remove
    xx <- cbind.data.frame(xx, icessquare= rep(0,nrow(xx)))


    rlong      <- range(anf(xx$SI_LONG),na.rm=T)
    vect.long  <- signif(seq(floor(rlong[1]), ceiling(rlong[2]), by=1),4)   # long (x)
    label.long <- rep(paste(rep(LETTERS,each=10),0:9,sep=""),each=1)
    names(label.long) <- signif(seq(-50, 209, by=1),4)   # long (x)
    label.long <- label.long[!is.na(names(label.long))]  # => correspondance long (-50 to 209) / sq letter (A0 to Z9)
    label.long <- label.long[as.character(vect.long)]
    rlat      <- range(anf(xx$SI_LATI), na.rm=T)
    vect.lat   <- signif(seq(floor(rlat[1]), ceiling(rlat[2]),by=0.5),4) # lat  (y)
    label.lat  <- rep(paste(seq(1,75,1)),each=1)
    names(label.lat) <-   paste(signif(seq(36,73, by=0.5),4))
    label.lat <- label.lat[!is.na(names(label.lat))] # => correspondance lat (36 to 73) / sq number (1 to 75)
    label.lat <- label.lat[as.character(vect.lat)]
    vect.label <- paste(rep(label.lat,each=length(label.long)),"",label.long,sep="")
    xx[,"SI_RECT"] <- paste(label.lat [findInterval(anf(xx[,"SI_LATI"]), vect.lat)] , label.long [findInterval(anf(xx[,"SI_LONG"]), vect.long)], sep="")

   return(xx)
   }


   #!!!!!!!!!!!!!!!!!!!!!#
   #utils--
   # for managing NA on logbook side
   # (from vms trip.sq without corresponding logbook trip.sq e.g. because no declaration in sq because only steaming time inside)
   # we need to inform back the specificity of the vessel from logbook using info from the same trip i.e. vesselid+FT_REF
   retrieveOnBkSide <- function(merged, type.data){
      idx <- which(merged$LE_MET_level6=="NA")
      merged.NA <- merged[idx,] # input (only the trip.sq with NA for the logbook part)

      for (td in type.data){
         map <- tapply(merged[, td ], paste(merged$VE_REF, merged$FT_REF),
                             function(i) {ss<- unique(as.character(i)) ; ss[ss!="NA"][1]})
         merged.NA[, td ] <- factor(paste(merged.NA$VE_REF,merged.NA$FT_REF))
         levels(merged.NA[, td ]) <- map[levels(merged.NA[, td ])]
         }
      if(nrow(merged.NA)>0) merged.NA$flag <- 4 # flag on meth
      merged[idx,] <- merged.NA # output
      return(merged)
      }

      #!#!##!#!##!#!##!#!##!#!##!#!#
      #!#!##!#!##!#!##!#!##!#!##!#!#
      #!#!##!#!##!#!##!#!##!#!##!#!#
      #!#!##!#!##!#!##!#!##!#!##!#!#
      #!#!##!#!##!#!##!#!##!#!##!#!#
      all.vesselid     <- as.character(unique(logbooks[anf(logbooks$VE_LEN)>=0,]$VE_REF)) 
      all.vesselid     <- all.vesselid[!is.na(all.vesselid)] # e.g. when VE_LEN at NA exists     
      if(length(lstargs$a.vesselid)!=0) all.vesselid <- lstargs$a.vesselid 
       # => IF ARG INFORMED, THEN KEEP ONLY ONE OR SEVERAL VESSELS AS NEEDED....

      for(a.vesselid in all.vesselid){  # PER VESSEL
                cat(paste(a.vesselid,"\n", sep="" ))
       
         #----------
         #----------
         #----------
         #----------
         #----------
         #----------
         # LOGBOOK INPUT
         logbk.this.vessel            <- logbooks[logbooks$VE_REF %in% a.vesselid,]
         logbk.this.vessel$LE_RECT    <- factor(logbk.this.vessel$LE_RECT)
         logbk.this.vessel$VE_REF     <- factor(logbk.this.vessel$VE_REF)
     
         # automatic detection of a.year
         general$a.year <-   format(strptime(  paste(logbk.this.vessel$FT_DDAT[1]) , tz='GMT',  "%e/%m/%Y" ), "%Y")
         
           # departure time
           logbk.this.vessel$LE_DTIME <- as.POSIXct(  paste(logbk.this.vessel$FT_DDAT, logbk.this.vessel$FT_DTIME) ,
                                                                tz='GMT',  "%e/%m/%Y %H:%M" )
           # arrival time
           logbk.this.vessel$LE_LTIME <- as.POSIXct(  paste(logbk.this.vessel$FT_LDAT, logbk.this.vessel$FT_LTIME) ,
                                                                tz='GMT',  "%e/%m/%Y %H:%M" )
           # catch.date
           logbk.this.vessel$LE_CTIME <- as.POSIXct(  paste(logbk.this.vessel$LE_CDAT) , tz='GMT',  "%e/%m/%Y" )

           # mid time bk trips
           LE_MIDTIME <- rep(NA, nrow(logbk.this.vessel))
           dep <- logbk.this.vessel$LE_DTIME +10  # we artificially add +10min because bug in R if mid-time is 00:00:00
           arr <- logbk.this.vessel$LE_LTIME +1
           for(r in 1:length(dep)){
              LE_MIDTIME[r] <- as.character(seq(from=dep[r], to=arr[r], length.out = 3)[2])
              }
           logbk.this.vessel$LE_MIDTIME          <-  LE_MIDTIME
          
           if(!"FT_REF" %in% colnames(logbk.this.vessel) ) {
             logbk.this.vessel$FT_REF              <-  factor(LE_MIDTIME) # init        
             levels(logbk.this.vessel$FT_REF)      <- 1:length(logbk.this.vessel$FT_REF) # assign a FT_REF code
             }   # only if FT_REF is actually not already informed
          
                           
     
           
         #=> LOGBOOK (EFLALO) INPUT REQUIRES AT LEAST,
         #     'VE_REF',  FT_DDAT, FT_DTIME, FT_LDAT, FT_LTIME, FT_CDAT,
         #  'LE_SP_KG' (etc.), 'LE_RECT', 'VE_FLT' AND 'LE_MET_level6', 'LE_GEAR' COLUMNS
         #

         #----------
         #----------
         #----------
         #----------
         #----------
         #----------
         # VMS INPUT: load traj with 'at sea' pings SI_STATE informed
         # ABSOLUTELY REQUIRED: c("VE_REF","SI_LATI","SI_LONG", "SI_DATE", "SI_TIME", "SI_FT", "SI_HARB", "SI_STATE")
    

         if(a.vesselid %in% unique(tacsat$VE_REF)){
      
         tacsat.this.vessel <- tacsat[tacsat$VE_REF == a.vesselid,] # subset for this vessel
         tacsat.this.vessel$VE_REF <- factor(tacsat.this.vessel$VE_REF)
         
 
         # if does not exist, add SI_DATIM for handling the time in R
         if(!("SI_DATIM" %in% colnames(tacsat))){
          tacsat.this.vessel$SI_TIME <- as.character(tacsat.this.vessel$SI_TIME)
          tacsat.this.vessel[tacsat.this.vessel$SI_TIME=="24:00", "SI_TIME"] <- "00:00"  # debug
          tacsat.this.vessel$SI_DATIM <- as.POSIXct(  paste(tacsat.this.vessel$SI_DATE, tacsat.this.vessel$SI_TIME) , 
                                 tz='GMT',   "%d/%m/%Y %H:%M" )
         }

         # keep only the essential
         vms.this.vessel  <- tacsat.this.vessel [, c("VE_REF","SI_LATI","SI_LONG", 
                          "SI_DATIM","SI_FT", "SI_SP", "SI_HE", "SI_HARB", "SI_STATE")]
         rm(tacsat.this.vessel); gc(reset=TRUE)                  
         vms.this.vessel$VE_REF   <- factor(vms.this.vessel$VE_REF)

         vms.this.vessel$idx  <- 1:nrow(vms.this.vessel) # label for each ping


        
 
         # filter if vessel with a bad vms
         to.remove.because.deficient.vms <- any(is.na(vms.this.vessel$SI_FT))
         to.remove.because.not.enough.vms.trips <- length(unique(vms.this.vessel$SI_FT))< 2  # nb vms trips < 2
         if(length(unique(vms.this.vessel$SI_FT))<2) warning('need more than 1 trip in SI_FT')
        
         # filter if vessel with a bad logbook
         to.remove.because.pble.lgbk <- length(unique(logbk.this.vessel$FT_REF))< 2  # nb logbk trips < 2
        
         # then...
         a.flag <- to.remove.because.deficient.vms ||  to.remove.because.not.enough.vms.trips || to.remove.because.pble.lgbk
         
         ## remove FT_REF and SI_MIDTIME if it exists
         vms.this.vessel <- vms.this.vessel[, !colnames(vms.this.vessel) %in% c("FT_REF", "SI_MIDTIME")]



        if(a.flag==FALSE) {  # i.e. vms-equipped

           if(all(is.na(vms.this.vessel$SI_STATE)) && general$do.wp3==FALSE)
                  stop('the SI_STATE column has to be informed before making the merging')
           if(all(is.na(logbk.this.vessel$VE_FLT)))
                  stop('the VE_FLT column has to be informed before making the merging')
     
         # alias
         .logbk <- logbk.this.vessel
         .vms   <- vms.this.vessel

         #!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#
         #!  DO THE LINK - APPROACH 1 #!#!!#!#!#!#!#!#!#!#
         #!#!#!#!#!#!#!#!!#!#!#!#!#!#!#!!#!#!#!#!#!#!#!#!#
         #!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#
NIELS <- FALSE
       if(NIELS){
           eftim <- .logbk[which(duplicated(.logbk$FT_REF)==F),c("LE_DTIME","LE_LTIME","FT_REF")]
           dtime <- eftim[,1]
           ltime <- eftim[,2]
           stime <- .vms$SI_DATIM
           tripn <- eftim[,3]
                            
                               
               
                              smdtime <- t(outer(stime,dtime,"-"))
                              gtltime <- outer(ltime,stime,"-")
                            
                              #-Find first point where tacsat time is greater or equal to departure time and smaller than arrival time
                              st <- apply(smdtime,1,function(x){which(x>=0)[1]})
                              en <- apply(gtltime,1,function(x){rev(which(x>=0))[1]})
                              
                              #-Make sure that values are within the interval of departure and arrival time
                              subse <- which(is.na(st <= en) == F & (st <= en) == T)
                              
                              st <- st[subse]
                              en <- en[subse]
                              
                              #-Assign Tacsat data with FT_REF from Eflalo2 dataset where they link
                              
                              if(length(st)!=1){
                          
                                idx   <- unlist(mapply(seq,st,en,SIMPLIFY=FALSE))
                                reps  <- unlist(lapply(mapply(seq,st,en,SIMPLIFY=FALSE),length))
                                .vms$FT_REF      <- 0
                                .vms$FT_REF[idx] <- rep(tripn[subse],reps)
                              } 
                              if(length(st)==1){
                                .vms$FT_REF <- 0
                                .vms$FT_REF[seq(st,en)] <- rep(tripn[subse],length(seq(st,en)))
                              }
                              if(length(st)==0){
                     
                                .vms$FT_REF <- 0
                              }
                          
                          
           } # end NIELS               

   FRANCOIS <- TRUE
   if(FRANCOIS){
         #!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#
         #!  DO THE LINK - APPROACH 2 #!#!!#!#!#!#!#!#!#!#
         #!#!#!#!#!#!#!#!!#!#!#!#!#!#!#!!#!#!#!#!#!#!#!#!#
         #!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#

         #!!!!!!!!!!!!!!!!!!#
         #!!!!!!!!!!!!!!!!!!#
         # -If IT DOES NOT EXIST YET-,
         # FIND THE MID-TIME OF VMS TRIPS
         if(any(colnames(.vms)%in%"SI_DATIM")){
           if(!any(colnames(.vms)%in%"SI_DTIME")){
            # find and add the first point of each trip
           .vms$start.trip <- c(1,diff(.vms[,"SI_FT"]))
           .vms$end.trip <- c(diff(.vms[,"SI_FT"]),0)
           .vms[.vms$start.trip>0, "start.trip"] <- .vms[.vms$start.trip>0, "SI_FT"]
           .vms[.vms$end.trip>0, "end.trip"] <- .vms[.vms$end.trip>0, "SI_FT"]

           tmp <- .vms[.vms$start.trip>0,]
           tmp <- tmp[,c("VE_REF","SI_DATIM","SI_FT")]
           tmp2 <- .vms[.vms$end.trip>0,]
           tmp2 <- tmp2[,c("VE_REF","SI_DATIM","SI_FT")]
           .vms <- .vms[,!colnames(.vms) %in% c("start.trip", "end.trip")] # remove tool columns
           table.midtime <- merge(tmp, tmp2, by.x="SI_FT", by.y="SI_FT")
           table.midtime <- table.midtime[, c("SI_FT","VE_REF.x","SI_DATIM.x","SI_DATIM.y") ]
           colnames(table.midtime) <- c("SI_FT","VE_REF","SI_DTIME","SI_ATIME")
           } else{
           table.midtime <- .vms[, c("SI_FT","VE_REF","SI_DTIME","SI_ATIME") ]
           table.midtime <- table.midtime[!duplicated(data.frame(table.midtime$SI_FT, table.midtime$VE_REF)),]
           }
         } else{stop("no 'SI_DATIM' found in vms")}
         SI_MIDTIME <- rep(0, nrow(table.midtime))
         for(r in 1: nrow(table.midtime)){
           SI_MIDTIME[r] <-  as.character(seq(from=table.midtime$SI_DTIME[r], to=table.midtime$SI_ATIME[r], length.out = 3)[2])
         
         }
         table.midtime$SI_MIDTIME <-  SI_MIDTIME
         if(!any(colnames(.vms)%in%"SI_MIDTIME")){ # here we are...
              .vms <- merge(.vms, table.midtime[,c("SI_FT","SI_MIDTIME")], by.x="SI_FT", by.y="SI_FT")
         }



        #!!!!!!!!!!!!!!!!!!#
        #!!!!!!!!!!!!!!!!!!#
        # ASSIGN A 'BK.TRIPNUM' FROM LOGBOOK TO EACH VMS TRIP
         trunk <-1 # trunk give the part of the year to be plotted (1 to 5)
         # visual check
         if(general$visual.check){
            windows(width=8, height=4)
            ltrunk <- (nrow(table.midtime)/5)
            idxtrunk <-  (trunk+(trunk-1)*ltrunk):(trunk*ltrunk)
        #    plot(table.midtime$SI_DTIME[idxtrunk],rep(1,length(table.midtime$SI_DTIME[idxtrunk])),
             plot(table.midtime$SI_DTIME, rep(1,length(table.midtime$SI_DTIME)),
                 ylim=c(0,0.52), type="n", ylab="", axes=FALSE)
            r <- as.POSIXct(round(range(table.midtime$SI_DTIME), "days"))
            axis.POSIXct(1, at=seq(r[1], r[2], by="month"), format="%e%b%y:%H:%M")
            axis(2, at=c(0.5,0.1),labels=c("VMS","LOGBOOK"))

            for(i in 1:nrow(table.midtime))  {
              segments(as.POSIXct(table.midtime$SI_DTIME[i]), 0.5, as.POSIXct(table.midtime$SI_ATIME[i]), 0.5, col=1)
              points(as.POSIXct(table.midtime$SI_MIDTIME[i]), 0.5, col=1)
              text(as.POSIXct(table.midtime$SI_MIDTIME[i]), 0.52, table.midtime$SI_FT[i], cex=0.5, col=1)
    
            }

            tmp <- .logbk[, c("LE_DTIME","LE_LTIME", "LE_MIDTIME", "FT_REF")]
            tmp <- tmp[!duplicated(tmp$LE_MIDTIME), ]
            for(i in 1:nrow(tmp)){
              segments(as.POSIXct(tmp$LE_DTIME[i]), 0.1, as.POSIXct(tmp$LE_LTIME[i]), 0.1, col=1)
              points(as.POSIXct(tmp$LE_MIDTIME[i]), 0.1, col=1)
              text(as.POSIXct(tmp$LE_MIDTIME[i]), 0.0785, tmp$FT_REF[i], cex=0.5, col=1)
            }
          }
         

          # THE CORE CODE: compare bk$LE_MIDTIME and vms$SI_MIDTIME
          # find the nearest bk$LE_MIDTIME for each vms$SI_MIDTIME
          # and then change levels
          # (so, for each mid.time in vms, a FT_REF will be find)
          # (so, no lines in vms without a FT_REF from bk...)
          fa1 <- levels(factor(.vms$SI_MIDTIME))
          new.levels <- fa1
          fa2 <-  levels(factor(.logbk$LE_MIDTIME))
          for(i in 1:length(fa1)) { # for each level in vms
             tmp <-  abs(as.numeric( as.POSIXct(fa2) - as.POSIXct(fa1)[i] ))
             if(all(is.na(tmp))) tmp <- abs(as.numeric( as.Date(fa2) - as.Date(fa1)[i] )) # debug the R bug in case of mid-time at 00:00 hour
             new.levels[i] <- fa2 [which(tmp == min(tmp, na.rm=T) )]  # find the nearest level in logbook
          }
          .vms$SI_MIDTIME <- factor(as.character(.vms$SI_MIDTIME))
          sauv <- .vms$SI_MIDTIME
          levels(.vms$SI_MIDTIME) <- new.levels # and change mid.time in vms to force the merging

          # finally, replace levels by the FT_REF
          tmp <-  .logbk[.logbk$LE_MIDTIME %in% .vms$SI_MIDTIME , c("FT_REF","LE_MIDTIME")]
          tmp2 <- tmp[!duplicated(tmp$FT_REF),]
          idx <- match( levels(.vms$SI_MIDTIME), tmp2$LE_MIDTIME )
          .vms$FT_REF <- .vms$SI_MIDTIME # init
          levels(.vms$FT_REF) <- as.character(tmp2$FT_REF )   [idx]


          if(general$visual.check){
            for(i in 1: nrow(.vms))  {
               arrows(as.POSIXct( sauv[i]), 0.5 ,as.POSIXct( .vms$SI_MIDTIME[i]),0.1, length=0.1)
            }
          }

          if(general$visual.check){
            ve <- as.character(.logbk$VE_REF[1])
            savePlot(filename = file.path(general$output.path,
                            paste("assign_eflalo_tripnum_to_vms_",ve,"_",general$a.year,".jpeg",sep="")),type ="jpeg")
           dev.off()
          }

     
        ## ADD A WARNING IN CASE OF LONG (UNREALISTIC) TRIPS ##
        diff.date <- table.midtime$SI_ATIME - table.midtime$SI_DTIME    # if at least one trip >30 days
        if(attributes(diff.date)$units=="secs")  idx <- which((((diff.date)/3600)/24) >30)  
        if(attributes(diff.date)$units=="hours")  idx <- which((((diff.date)/1)/24) >30)  
        attributes((table.midtime$SI_ATIME - table.midtime$SI_DTIME ))
        if (length( idx) >0){
             cat(paste("at least one vms trip > 30 days detected! check harbours...", "\n", sep=""))
            suspicious <- .vms[.vms$SI_FT %in%  table.midtime$SI_FT[idx] ,]
            tmp <- table(suspicious$SI_LATI)
            lat.suspicious <- names(tmp[tmp>5]) 
            if(length(lat.suspicious)!=0) cat(paste("potential harbour likely near lat ",lat.suspicious,"\n",sep=""))
            tmp <- table(suspicious$SI_LONG)
            long.suspicious <- names(tmp[tmp>5]) 
            if(length(long.suspicious)!=0) cat(paste("potential harbour likely near long ",long.suspicious,"\n",sep=""))
            }  # if at least one trip >30 days
        rm(table.midtime) ; gc(reset=TRUE)  

     
       
         .logbk$LE_MIDTIME    <- factor(.logbk$LE_MIDTIME)
         .logbk$FT_REF        <- factor(.logbk$FT_REF)
         .vms$SI_MIDTIME      <- factor(.vms$SI_MIDTIME)
         .vms$FT_REF          <- factor(.vms$FT_REF)

         #!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#
         #! ASSIGN A 'SI_FT' FROM VMS TRIP NUM TO  #!#!#!#
         #! LOGBOOK TRIPS WITH NO VMS CORRESPONDANCE #!#!#
         #!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#
       dep.bk.not.in.vms  <- unique( .logbk$FT_REF [ !( .logbk$FT_REF %in%  .vms$FT_REF )  ] )
       if(length(dep.bk.not.in.vms)!=0){
         # bk tripnum from dep not in vms
         idx <-  .logbk$FT_REF %in% dep.bk.not.in.vms
         bk  <- .logbk[idx,] [order(.logbk[idx,]$LE_DTIME),]
         if(!"SI_MIDTIME" %in% colnames(.vms)){
            vms <- .vms  [order(.vms$SI_DTIME),]
            SI_MIDTIME <- rep(NA, nrow(vms))
            for(r in 1: nrow(vms)){
              SI_MIDTIME[r] <-  as.character(seq(from=vms$SI_DTIME[r], to=vms$SI_ATIME[r], length.out = 3)[2])
            }
            vms$SI_MIDTIME <-  SI_MIDTIME
         } else{ vms <- .vms[order(.vms$SI_MIDTIME),]}
         #1- compare bk$mid.time and vms$mid.time
         # find the nearest vms$mid.time for each bk$mid.time
         # and then change levels
         # (so for each mid.time in bk, a tripnum will be find)
         # (so no lines in bk without a tripnum...)
         fa1 <- levels(factor(bk$LE_MIDTIME))
         new.levels <- fa1
         fa2 <-  levels(factor(vms$SI_MIDTIME))
         for(i in 1:length(fa1)) { # for each level in logbk
          tmp <-  abs(as.numeric( as.POSIXct(fa2) - as.POSIXct(fa1)[i] ))
          new.levels[i] <- fa2 [which(tmp == min(tmp, na.rm=T) )]  # find the nearest level in vms
         }
         bk$LE_MIDTIME <- factor(as.character(bk$LE_MIDTIME))
         levels(bk$LE_MIDTIME) <- new.levels # and change mid.time in logbk to force the merging

         # finally, replace levels by the tripnum
         # (note: a same FT_REF in vms can have different mid.time
         # due to the first merging of vms to logbk in the vms analysis)
         tmp <-  vms[vms$SI_MIDTIME %in% bk$LE_MIDTIME , c("FT_REF","SI_MIDTIME")]
         tmp2 <- tmp[!duplicated(data.frame(tmp$FT_REF, tmp$SI_MIDTIME)),]
         idx2 <- match(levels(bk$LE_MIDTIME), tmp2$SI_MIDTIME)
         bk$FT_REF <- bk$LE_MIDTIME # init
         levels(bk$FT_REF)  <- as.character(tmp2$FT_REF) [idx2]

         # output
         bk$LE_MIDTIME   <- as.character(bk$LE_MIDTIME)
         bk$FT_REF <- as.character(bk$FT_REF)
         .logbk[idx,][order(.logbk[idx,]$LE_DTIME),]  <- bk
         }


        } # end FRANCOIS


         #!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#
         # ASSIGN A RECTANGLE TO EACH PING #!#!#!#!#!#!#!#
         #!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#
         .vms   <- assignPointsToSpatialGrid(xx=.vms)
        
         #!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#
         # COMPUTE EFFORT.MINS      !#!#!#!#!#!#!#!#!#!#!#
         #!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#
          .vms <- .vms[order(.vms$SI_DATIM),]
          .vms$LE_EFF_VMS <- abs(c(0, as.numeric(.vms[-nrow(.vms),"SI_DATIM"] - 
                                        .vms[-1,"SI_DATIM"], units="mins")))
           start.trip <- c(1,diff(.vms[,"SI_FT"]))
          .vms[start.trip!=0, "LE_EFF_VMS"] <- 0  # just correct for the trip change points


         #!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#
         # ASSIGN FISHING/NON-FISHING (optional)!#!#!#!#!#
         #!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#
         if(general$do.wp3 && general$speed=="segment") {
             ## add a gear form tacsat from the logbook info (after the first merging)
             ## because the assignement of a state is gear-specific.
             ## caution here: we assume only one gear used inside a trip...
             # because note that we remove 'logevent' and keep only one duplicate of tripnum
             .vms$LE_GEAR <- factor(.vms$FT_REF) # init
             tmp <- .logbk[,c("LE_GEAR","FT_REF")]
             tmp <- tmp[!duplicated(tmp$FT_REF),] #remove logevent and keep only one duplicate of tripnum
             tmp <- tmp[tmp$FT_REF %in% unique(.vms$LE_GEAR),]
             idx <- match(levels(.vms$LE_GEAR), as.character(tmp$FT_REF))
             dd  <-  as.character(tmp$LE_GEAR)  [idx]
             dd  <- replace(dd, is.na(dd), "UKN") # unknown because not matched if Niels
            levels(.vms$LE_GEAR) <- dd
     
             # then do the assignement of the state 
             #according to a segemented regression on the (apparent) speed histogram
            .vms <- segmentTacsatSpeed (tacsat=.vms, vessels=a.vesselid, 
                                  force.lower.bound=0.5, general=list(a.year=general$a.year,
                                   output.path=general$output.path, visual.check=TRUE))
                #=> (semi)automatic detection of the fishing peak
                # (put here because the LE_GEAR need to be informed)
            
            .vms <- .vms[, !colnames(.vms) %in% "LE_GEAR"] # remove after use to avoid future conflict.
         }
         # some alternatives TO DO:
         #if(general$do.wp3 && general$speed=="lookuptable")
         #   .vms <- lookupSpeedTacsat (tacsat=.vms, vessels=a.vesselid)
         #if(general$do.wp3 && general$speed=="bayesian")
         #   .vms <- bayesianFiltering (tacsat=.vms, vessels=a.vesselid)
         


         rm(er); rm(xx) ; gc(reset=TRUE)
                                           
         #!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#
         # SET UP PRIMARY KEYS FOR MERGING!#!#!#!#!#!#!#!#
         #!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#
         .logbk$FT_REF <- factor(.logbk$FT_REF )
         .logbk$FT_REF_SQ <- paste(.logbk$FT_REF, ".", .logbk$LE_RECT, sep='') 
         .logbk$FT_REF_SQ_DAY <- paste(.logbk$FT_REF, ".", .logbk$LE_RECT,".", an(format(.logbk$LE_CTIME,  '%j')), sep='') 
         .vms$FT_REF <- factor(.vms$FT_REF)
         .vms$FT_REF_SQ <- paste(.vms$FT_REF, ".", .vms$SI_RECT, sep='') 
         .vms$FT_REF_SQ_DAY <- paste(.vms$FT_REF, ".", .vms$SI_RECT,".", an(format(.vms$SI_DATIM,  '%j')), sep='') 

         # for gear, if several gears inside a same trip,
         #  it is problematic because we have to assume a split of total effort or toal nb of ping between gears...


           #!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#
           # AGGREGATE WEIGHT PER SPECIES !#!#!#!#!#!#!#!#!#
           #!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#
           nm         <- names(.logbk)
           idx.col.w  <- grep('KG', nm) # index columns with species weight
           idx.col.v  <- grep('EURO', nm) # index columns with species value
           idx.col    <- c(idx.col.w, idx.col.v)
             # AGGREGATE WEIGHT (OR VALUE) PER SPECIES PER FT_REF
              agg.logbk.this.vessel.method.1  <- aggregate(.logbk[,idx.col],
                      list(.logbk$FT_REF, 
                              .logbk$VE_REF,  .logbk$VE_FLT,.logbk$VE_KW,  .logbk$LE_MET_level6, .logbk$LE_GEAR), sum, na.rm=TRUE )
              colnames(agg.logbk.this.vessel.method.1) <- 
                           c("FT_REF", "VE_REF",  "VE_FLT", "VE_KW","LE_MET_level6","LE_GEAR", nm[idx.col] )
             # AGGREGATE WEIGHT (OR VALUE) PER SPECIES PER FT_REF_SQ
              agg.logbk.this.vessel.method.2  <- aggregate(.logbk[,idx.col],
                      list(.logbk$FT_REF_SQ, 
                              .logbk$VE_REF,  .logbk$VE_FLT,.logbk$VE_KW,  .logbk$LE_MET_level6, .logbk$LE_GEAR), sum, na.rm=TRUE )
              colnames(agg.logbk.this.vessel.method.2) <- 
                           c("FT_REF_SQ", "VE_REF",  "VE_FLT","VE_KW","LE_MET_level6" ,"LE_GEAR", nm[idx.col])
             # AGGREGATE WEIGHT (OR VALUE) PER SPECIES PER FT_REF_SQ_DAY (NOTE: SO, 'LE_SEQNUM' IS AGGREGATED HERE)
              agg.logbk.this.vessel.method.3  <- aggregate(.logbk[,idx.col],
                      list(.logbk$FT_REF_SQ_DAY, 
                             .logbk$VE_REF,  .logbk$VE_FLT, .logbk$VE_KW,  .logbk$LE_MET_level6, .logbk$LE_GEAR), sum, na.rm=TRUE )
              colnames(agg.logbk.this.vessel.method.3) <- 
                          c("FT_REF_SQ_DAY", "VE_REF", "VE_FLT","VE_KW", "LE_MET_level6","LE_GEAR",  nm[idx.col])


             #!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#
             # MERGING WITH VMS PER TRIP !!!!!!!!!!#!#!#!#!#!#
             #!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#
             do.merging <- function(method="FT_REF", .logbk, .vms, general){


             
                
              # IF BY PING-------------
              # find total nb of FISHING ping per tripnum from vms  # used for method 1  'FT_REF'
              if(method=="FT_REF"){
 #              .vms$count.fping.trip  <- factor(.vms$FT_REF)  # init
 #             count.fping.trip <- table(.vms[.vms$SI_STATE==1,]$FT_REF)
 #             # => COUNT nb of FISHING pings per FT_REF because each weight will be repeated by ping after merging
 #             levels(.vms$count.fping.trip) <- count.fping.trip[levels(.vms$count.fping.trip)]  # mapping
 #             .vms[.vms$SI_STATE==2,]$count.fping.trip <- NA
           
              # => COUNT nb of FISHING pings per FT_REF because each weight will be repeated by ping after merging
              .vms$count.fping.trip             <- factor(.vms$FT_REF)  # init
              countp                            <- countPings(~VE_REF+FT_REF, .vms[.vms$SI_STATE=="1",])
              rownames(countp)                  <-  countp$FT_REF  
              levels(.vms$count.fping.trip)     <- countp[levels(.vms$count.fping.trip),"pings"]    # mapping
              .vms[.vms$SI_STATE==2,]$count.fping.trip <- NA
     
              # => COUNT nb of gears per FT_REF because each ping will be repeated by gear after merging
              count.gr.trip <- tapply(.logbk$LE_GEAR, .logbk$FT_REF, function(x) length(unique(x)))
              .logbk$count.gr.trip <- count.gr.trip[.logbk$FT_REF]  # mapping
              
               }


              # find total nb of FISHING ping per trip-icessquare from vms  # used for method 2   'FT_REF_SQ'
              if(method=="FT_REF_SQ"){
     #         .vms$count.fping.trip.sq  <- factor(.vms$FT_REF_SQ)  # init
     #         count.fping.trip.sq <- table(.vms[.vms$SI_STATE==1,]$FT_REF_SQ) # COUNT nb of FISHING pings per FT_REF_SQ
     #         levels(.vms$count.fping.trip.sq) <- count.fping.trip.sq[levels(.vms$count.fping.trip.sq)]  # mapping
     #         if(any('2' %in% unique(.vms$SI_STATE))) .vms[.vms$SI_STATE==2,]$count.fping.trip.sq <- NA
     
              .vms$count.fping.trip.sq          <- factor(.vms$FT_REF_SQ)  # init
              countp                            <- countPings(~VE_REF+SI_RECT+FT_REF, .vms[.vms$SI_STATE=="1",])
              rownames(countp)                  <-  interaction(countp$FT_REF,countp$SI_RECT)  
              levels(.vms$count.fping.trip.sq ) <- countp[levels(.vms$count.fping.trip.sq),"pings"]    # mapping
              if(any('2' %in% unique(.vms$SI_STATE))) .vms[.vms$SI_STATE==2,]$count.fping.trip.sq <- NA
     
     
              # => COUNT nb of gears per FT_REF_SQ because each ping will be repeated by gear after merging
              count.gr.trip.sq <- tapply(.logbk$LE_GEAR, .logbk$FT_REF_SQ, function(x) length(unique(x)))
              .logbk$count.gr.trip.sq <- count.gr.trip.sq[.logbk$FT_REF_SQ]  # mapping
              }


              # find total nb of FISHING ping per trip-icessquare-day from vms  # used for method 3   'FT_REF_SQ_DAY'
              if(method=="FT_REF_SQ_DAY"){
#              .vms$count.fping.trip.sq.day  <- factor(.vms$FT_REF_SQ_DAY)  # init
#              count.fping.trip.sq.day <- table(.vms[.vms$SI_STATE==1,]$FT_REF_SQ_DAY) # COUNT nb of FISHING pings per FT_REF_SQ_DAY
#              levels(.vms$count.fping.trip.sq.day) <- count.fping.trip.sq.day[levels(.vms$count.fping.trip.sq.day)]  # mapping
#              if(any('2' %in% unique(.vms$SI_STATE))) .vms[.vms$SI_STATE==2,]$count.fping.trip.sq.day <- NA


              .vms$count.fping.trip.sq.day          <- factor(.vms$FT_REF_SQ_DAY)  # init
              countp                                <- countPings(~VE_REF+day+SI_RECT+FT_REF, .vms[.vms$SI_STATE=="1",])
              rownames(countp)                      <-  interaction(countp$FT_REF, countp$SI_RECT, countp$SI_DAY)  
              levels(.vms$count.fping.trip.sq.day) <- countp[levels(.vms$count.fping.trip.sq.day),"pings"]    # mapping
              if(any('2' %in% unique(.vms$SI_STATE))) .vms[.vms$SI_STATE==2,]$count.fping.trip.sq.day <- NA


              # => COUNT nb of gears per FT_REF_SQ_DAY because each ping will be repeated by gear after merging
              count.gr.trip.sq.day <- tapply(.logbk$LE_GEAR, .logbk$FT_REF_SQ_DAY, function(x) length(unique(x)))
              .logbk$count.gr.trip.sq.day <- count.gr.trip.sq.day[.logbk$FT_REF_SQ_DAY]  # mapping}
              }



              # do the merging between .logbk and .vms according to
              #  meth1: 'FT_REF' OR meth2: 'FT_REF_SQ' OR meth3: 'FT_REF_SQ_DAY'
              # need to use a trick to avoid "out of memory" doing the merge()
              coln.idx1 <- which(!colnames(.logbk)%in%c("VE_REF", method))
              coln1 <- colnames(.logbk)[coln.idx1]
              tmp1 <- data.frame(coll= collapse.all.columns  (.logbk, columns= coln.idx1  ),
                         VE_REF=.logbk$VE_REF, a.method= .logbk[,method] ) #.logbk
              coln.idx2 <- which(!colnames(.vms)%in%c("VE_REF", method))
              coln2 <- colnames(.vms)[coln.idx2]
              tmp2 <- data.frame(coll2= collapse.all.columns  (.vms, columns=  coln.idx2 ),
                         VE_REF=.vms$VE_REF, a.method= .vms[,method] )  #.vms
              tmp1[,"a.method"] <- factor(tmp1[,"a.method"] )
              tmp2[,"a.method"] <- factor(tmp2[,"a.method"] )

              merged.this.vessel <- merge(tmp1, tmp2, all.x=TRUE, all.y=TRUE, suffixes = c(".bk",".vms"))
              #=> so, with all.y = TRUE, the vms records without corresponding logbk records are kept and NA are produced on the logbook part
              #=> so, with all.x = TRUE, the logbk records  without corresponding vms records are kept and NA are produced on the vms part
              merged.this.vessel$coll <- replace(as.character(merged.this.vessel$coll),is.na(merged.this.vessel$coll), paste(rep("NA",length(coln1)),collapse="#"))
              merged.this.vessel$coll <- factor(merged.this.vessel$coll)
              #=> adapt 'coll' to get a vector of NA (NA in case of 'in vms but not in logbook')
              merged.this.vessel$coll2 <- replace(as.character(merged.this.vessel$coll2),is.na(merged.this.vessel$coll2), paste(rep("NA",length(coln2)),collapse="#"))
              # adapt 'coll2' to get a vector of NA (NA in case of 'in logbook but not in vms')
              merged.this.vessel$coll2 <- factor(merged.this.vessel$coll2)
              colnames(merged.this.vessel)[colnames(merged.this.vessel)%in%"a.method"] <- method

              tmp3 <- uncollapse.column(merged.this.vessel, column="coll")  # logbk
              tmp4 <- uncollapse.column(merged.this.vessel, column="coll2") # vms
              tmp5 <- cbind.data.frame(merged.this.vessel[,c("VE_REF", method)], tmp3, tmp4)
              colnames(tmp5) <- c("VE_REF", method, coln1, coln2)
              merged.this.vessel <- tmp5

              # we can choose to correct to keep the land. weight:
              # the loss in weight will come from the matching records having catches but
              # without fishing pings (i.e. only steaming pings)!
              if(is.null(general$conserve.all)) general$conserve.all <- FALSE
              if(general$conserve.all){
              # do the conservation of landings anyway?
              # detect possible weight landed while no feffort detected from vms
                   # find FT_REF with some NA
                   vv<- anf(unique(merged.this.vessel[merged.this.vessel$count.fping.trip=="NA","FT_REF"]))
                   # then, find FT_REF with at least one no NA
                   no.vv<- anf(unique(merged.this.vessel[merged.this.vessel$count.fping.trip!="NA","FT_REF"]))
                   tripnum.all.na.inside <- vv[!vv%in%no.vv] # trip num without at least one count.fping!
                   # so, deduce loss in weight
                   zz<- merged.this.vessel[merged.this.vessel$FT_REF %in% tripnum.all.na.inside,]
           
                  if(method=="FT_REF"){
                     # in this case, reallocate evenly between all pings (caution: including steaming pings)
                     merged.this.vessel[,"count.fping.trip"] <- anf(merged.this.vessel[,"count.fping.trip"])
                     merged.this.vessel$FT_REF <- factor( merged.this.vessel$FT_REF)
                     nbpings.per.trip <- unlist(lapply(split(merged.this.vessel[merged.this.vessel$FT_REF %in% tripnum.all.na.inside,],
                                           merged.this.vessel[merged.this.vessel$FT_REF %in% tripnum.all.na.inside,]$FT_REF),nrow))            
                     merged.this.vessel[merged.this.vessel$FT_REF %in% tripnum.all.na.inside, "count.fping.trip"] <- rep(nbpings.per.trip,nbpings.per.trip )
                     merged.this.vessel[merged.this.vessel$FT_REF %in% tripnum.all.na.inside, "flag"] <- 5
                    }
                } # end conserve.all

          

      
              # apply the catches re-distribution
              # method 1, 2 and 3: per ping
              # PER PING:
              # ASSUMING EQUAL ALLOCATION BETWEEN FISHING PINGS AND GEARS USE INSIDE A SAME TRIP
              nm        <- names(merged.this.vessel)
              idx.col.w <- grep('KG', nm) # index columns with species weight
              idx.col.v <- grep('EURO', nm) # index columns with species value
              idx.col <- c(idx.col.w, idx.col.v)
              if(method=="FT_REF_SQ_DAY"){
                             merged.this.vessel[,idx.col] <- (apply(merged.this.vessel[,idx.col],2,anf) /
                                                        anf(merged.this.vessel$count.fping.trip.sq.day)) /
                                                                        anf(merged.this.vessel$count.gr.trip.sq.day)
              }
              if(method=="FT_REF_SQ"){
                             merged.this.vessel[,idx.col] <- (apply(merged.this.vessel[,idx.col],2,anf) /
                                                        anf(merged.this.vessel$count.fping.trip.sq)) /
                                                                        anf(merged.this.vessel$count.gr.trip.sq)
              }
              if(method=="FT_REF"){
                         # maybe do more by adding unallocated landings to the midpoint of the trip**
                             merged.this.vessel[,idx.col] <- (apply(merged.this.vessel[,idx.col],2,anf) /
                                                           anf(merged.this.vessel$count.fping.trip) ) /
                                                                        anf(merged.this.vessel$count.gr.trip)
              }

      
        if(FALSE){  # HERE, BE AWARE OF A POSSIBLE LEAK IN LANDINGS...
              # conservation of catches?
              # detect possible weight landed while no feffort detected from vms
                   # find FT_REF with some NA
                   vv<- anf(unique(merged.this.vessel[merged.this.vessel$count.fping.trip=="NA","FT_REF"]))
                   # then, find FT_REF with at least one no NA
                   no.vv<- anf(unique(merged.this.vessel[merged.this.vessel$count.fping.trip!="NA","FT_REF"]))
                   tripnum.all.na.inside <- vv[!vv%in%no.vv] # trip num without at least one count.fping!
                   # so, deduce loss in weight
                   zz<- merged.this.vessel[merged.this.vessel$FT_REF %in% tripnum.all.na.inside,]
                   loss <- tapply(anf(zz$LE_KG_COD), zz$FT_REF, sum, na.rm=TRUE)
                   names(loss) <- paste(a.vesselid, names(loss), sep='.')
                   land.losses <<- c(land.losses, loss )

                cat(paste("weight loss for ", general$sp.to.keep[1]," (vms failure in fishing/steaming detection): ",
                      sum(anf(unique(zz$LE_KG_COD)), na.rm=TRUE),"\n", sep="" ))
              
             }  # TO DO**: assign landings to the mid point of the trip for trips with all na inside (i.e. only steaming detected while declared landings) 
                 # (i.e. assign 1 to in count.fping.trip for the mid point)

             
              return(merged.this.vessel)
              }



             #!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#
             # MERGING PROCEDURE CHOICE !#!#!#!#!#!#!#!#!#!#!#
             #!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#
          
                 .logbk   <- agg.logbk.this.vessel.method.3
                 my.split <- function(obj,a.sep="\\.",idx=1) unlist(lapply(strsplit(obj, a.sep),function(x)x[idx]))
                 # reduce the level
                 .logbk$FT_REF_SQ  <-  paste(my.split(as.character(.logbk$FT_REF_SQ_DAY),a.sep="\\.",idx=1),
                                                 my.split(as.character(.logbk$FT_REF_SQ_DAY),a.sep="\\.",idx=2),sep='.')
                 # reduce the level
                 .logbk$FT_REF     <-        my.split(as.character(.logbk$FT_REF_SQ),a.sep="\\.",idx=1)
                 # find common keys
                 tripnum.sq.day.logbk            <- .logbk$FT_REF_SQ_DAY
                 tripnum.sq.day.vms              <- .vms$FT_REF_SQ_DAY
                 tripnum.sq.logbk                <- .logbk$FT_REF_SQ
                 tripnum.sq.vms                  <- .vms$FT_REF_SQ
                 tripnum.sq.day.in.vms.and.in.bk <- tripnum.sq.day.vms [tripnum.sq.day.vms %in% tripnum.sq.day.logbk]
                 tripnum.sq.in.vms.and.in.bk     <- tripnum.sq.vms [tripnum.sq.vms %in% tripnum.sq.logbk]
                 .vms.in.bk                      <- .vms[ .vms$FT_REF_SQ_DAY %in%  tripnum.sq.day.in.vms.and.in.bk,]
                 .vms.in.bk2                     <- .vms[ !(.vms$FT_REF_SQ_DAY %in%  tripnum.sq.day.in.vms.and.in.bk) &
                                                            .vms$FT_REF_SQ %in%  tripnum.sq.in.vms.and.in.bk,]
                 in.bk.and.feffort.not.at.0   <- unique(.vms.in.bk[.vms.in.bk$SI_STATE==1,]$FT_REF_SQ_DAY)
                 in.bk2.and.feffort.not.at.0   <- unique(.vms.in.bk2[.vms.in.bk2$SI_STATE==1,]$FT_REF_SQ)
                 
                     # split .vms and .logbk in three blocks
                  # vms with good match => go to meth3
                 .vms.for.meth3         <- .vms [.vms$FT_REF_SQ_DAY %in%   in.bk.and.feffort.not.at.0, ]
                  # vms with intermediate match => go to meth2
                 .vms.for.meth2         <- .vms [!(.vms$FT_REF_SQ_DAY  %in%   in.bk.and.feffort.not.at.0) &
                                                      (.vms$FT_REF_SQ    %in%   in.bk2.and.feffort.not.at.0), ]
                  # vms with bad match => go to meth1
                 .vms.for.meth1         <- .vms [!(.vms$FT_REF_SQ_DAY  %in%   in.bk2.and.feffort.not.at.0) &
                                                      !(.vms$FT_REF_SQ  %in%   in.bk2.and.feffort.not.at.0), ]
                  # logbk with good match => go to meth3
                 .logbk.for.meth3       <- .logbk [.logbk$FT_REF_SQ_DAY %in%  in.bk.and.feffort.not.at.0, ]
                  # logbk with intermediate match => go to meth2
                 .logbk.for.meth2       <- .logbk [!(.logbk$FT_REF_SQ_DAY %in%   in.bk.and.feffort.not.at.0) &
                                                       (.logbk$FT_REF_SQ %in%  in.bk2.and.feffort.not.at.0), ]
                  # logbk with bad match => go to meth1
                 .logbk.for.meth1       <- .logbk [!(.logbk$FT_REF_SQ_DAY %in%   in.bk.and.feffort.not.at.0) &
                                                       !(.logbk$FT_REF_SQ %in%  in.bk2.and.feffort.not.at.0), ]

                 suppressWarnings(rm(merged1, merged2, merged3)) # clear
                 #!! METH1 !!#
                 if(nrow(.logbk.for.meth1)!=0 && nrow(.vms.for.meth1)!=0 ) {
                    # remove useless cols and aggregate according to the key 'FT_REF'
                    .logbk.for.meth1 <- .logbk.for.meth1[, !colnames(.logbk.for.meth1)%in% c("FT_REF_SQ_DAY","FT_REF_SQ")]
                    nm        <- names(.logbk.for.meth1)
                    idx.col.w <- grep('KG', nm) # index columns with species weight
                    idx.col.v <- grep('EURO', nm) # index columns with species value
                    idx.col <- c(idx.col.w, idx.col.v)
                    .logbk.for.meth1   <- aggregate(.logbk.for.meth1 [,idx.col],
                                 list(.logbk.for.meth1$VE_REF, .logbk.for.meth1$FT_REF,
                                            .logbk.for.meth1$VE_FLT, .logbk.for.meth1$VE_KW, .logbk.for.meth1$LE_MET_level6, .logbk.for.meth1$LE_GEAR), sum, na.rm=TRUE)
                    colnames(.logbk.for.meth1) <- c("VE_REF", "FT_REF", "VE_FLT", "VE_KW", "LE_MET_level6", "LE_GEAR", nm[idx.col])
                    # do.merging
                    merged1  <- do.merging(method="FT_REF", .logbk.for.meth1, .vms.for.meth1, general)
                    # add meth flag
                     if("flag" %in% names(merged1)  && nrow(merged1[is.na(merged1[,"flag"]),])!=0){
                        merged1[is.na(merged1[,"flag"]),"flag"] <- 1 # meth 1
                        } else merged1$flag <- 1
                    }
                 #!! METH2 !!#
                 if(nrow(.logbk.for.meth2)!=0 && nrow(.vms.for.meth2)!=0 ) {
                    # remove useless cols and aggregate according to the key 'FT_REF_SQ'
                    .logbk.for.meth2 <- .logbk.for.meth2[, !colnames(.logbk.for.meth2)%in% c("FT_REF_SQ_DAY","FT_REF")]
                    nm        <- names(.logbk.for.meth2)
                    idx.col.w <- grep('KG', nm) # index columns with species weight
                    idx.col.v <- grep('EURO', nm) # index columns with species value
                    idx.col <- c(idx.col.w, idx.col.v)
                    .logbk.for.meth2   <- aggregate(.logbk.for.meth2 [,idx.col],
                                 list(.logbk.for.meth2$VE_REF, .logbk.for.meth2$FT_REF_SQ,
                                            .logbk.for.meth2$VE_FLT, .logbk.for.meth2$VE_KW, .logbk.for.meth2$LE_MET_level6, .logbk.for.meth2$LE_GEAR), sum, na.rm=TRUE)
                    colnames(.logbk.for.meth2) <- c("VE_REF",  "FT_REF_SQ", "VE_FLT", "VE_KW", "LE_MET_level6", "LE_GEAR", nm[idx.col])
                    # do.merging
                    merged2 <- do.merging(method="FT_REF_SQ", .logbk.for.meth2, .vms.for.meth2, general)
                    # add meth flag
                    merged2$flag <- 2 # meth 2
                 }
                 #!! METH3 !!#
                 if(nrow(.logbk.for.meth3)!=0 && nrow(.vms.for.meth3)!=0 ) {
                    # do.merging
                    merged3 <- do.merging(method="FT_REF_SQ_DAY", .logbk.for.meth3, .vms.for.meth3, general)
                   # add meth flag
                    merged3$flag <- 3 # meth 3
                 }

                 # bind the three blocks
                 merged <- NULL ; colnm <- NULL
                 for(i in 1: 3){
                   a.table <- try(get(paste('merged',i,sep='')), silent=TRUE)
                   if(class(a.table)!="try-error"){
                     a.table <- a.table[, !colnames(a.table) %in%
                                  c("count.fping.trip.sq.day","count.fping.trip.sq","count.fping.trip",
                                      "tot.fish.effort.trip","tot.fish.effort.trip.sq",
                                         "count.gr.trip", "count.gr.trip.sq", "count.gr.trip.sq.day",
                                           "FT_REF_SQ", "FT_REF_SQ_DAY")] # remove tool columns
                     if(i==1) colnm <-  colnames(a.table) ; if(is.null(colnm)) colnm <-  colnames(a.table)
                     merged <- rbind.data.frame (merged, a.table[, colnm])
                     }
                   }
                 # if still 'not merging' part, retrieve on NA side i.e. occurs when pings in vms but not in bk
                   merged <- retrieveOnBkSide(merged, type.data=c( "VE_FLT","VE_KW","LE_MET_level6"))  # i.e. when metier=='NA'

     
        # clean up
        rm(a.table, merged1, merged2, merged3, merged.this.vessel,.vms, .logbk, logbk.this.vessel, vms.this.vessel)
        gc(reset=TRUE)
   
        # restore tacsat names               "%e/%m/%Y %H:%M"
        idx <- merged$SI_DATIM!='NA' # NA is possible when bk not in vms because bk.tripnum vms may belong to another block than block1
        merged$SI_DATIM <- as.character(merged$SI_DATIM)
        merged$SI_DATE  <- NA
        merged[idx,"SI_DATE"] <- paste(substr(merged[idx,]$SI_DATIM ,9,10),"/",
                                      substr(merged[idx,]$SI_DATIM , 6,7), "/", substr(merged[idx,]$SI_DATIM ,1,4), sep='')
        merged$SI_TIME  <- NA
        merged[idx,"SI_TIME"] <- paste(substr(merged[idx,]$SI_DATIM , 12,13),":",
                                      substr(merged[idx,]$SI_DATIM , 15,16), sep='')
    
        # last calculation 
        merged$KW_HOURS <- anf(merged$VE_KW) * anf(merged$LE_EFF_VMS)
    
        # order chronologically
        merged <- orderBy(~SI_DATIM, merged)

        # last clean up 
        merged <- merged[, !colnames(merged) %in% c('idx', 'icessquare', "SI_DATIM", "SI_MIDTIME")]
        
       # save------------
       save("merged",   file=file.path(general$output.path,
             paste("merged_",  a.vesselid,"_",general$a.year,".RData", sep='')))
       cat(paste("save 'merged'...OK\n\n",sep=""))
     

               }else{  # end 'a.flag'
     cat(paste("failure for",a.vesselid,"(probably not vms-equipped)\n"))
     # because no vms for this vessel...
     # TO DO: the logbk way
     #...
       }
     }else{  # end try-error
     cat(paste("failure for",a.vesselid,"(probably not vms-equipped)\n"))
     # because no vms for this vessel...
     # TO DO: the logbk way
     #...
     }




     } # end a.vesselid






return()
}






  ##!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!##
  ##!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!##
  ##!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!##
  ##!!!!!MAIN!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!##
  ##!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!##
  ##!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!##
  ##!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!##
 if(FALSE) {


  #\dontrun{
  data(eflalo2)
  data(tacsat)
  data(euharbours)
  # add some missing harbours to the list? 
  #euharbours <- c(euharbours, list(a.harbour1=data.frame(lon='10',lat='10', range='3')))
  #euharbours <- c(euharbours, list(a.harbour2=data.frame(,lon='1',lat='1', range='3')))

  # order tacsat chronologically with library(doBy) 
  tacsat <- sortTacsat(tacsat)

  # test each ping if in harbour or not
  tacsat$SI_HARB <- NA
  tacsat$SI_HARB <- pointInHarbour(lon=anf(tacsat$SI_LONG), lat=anf(tacsat$SI_LATI), harbours=euharbours, rowSize=30, returnNames=TRUE)
  inHarb <- tacsat$SI_HARB 
  inHarb <- replace(inHarb, !is.na(inHarb), 1)
  inHarb <- replace(inHarb, is.na(inHarb), 0)
  inHarb <- as.numeric(inHarb)
    
  # assign a trip identifier
  tacsat$SI_FT <- 1 # init
  idx <- which(inHarb==0)
  tacsat[idx,"SI_FT"] <- cumsum(inHarb) [idx] # add a SI_FT index
  
  # keep 'out of harbour' points only
  # (but keep the departure point lying in the harbour)
  startTrip <- c(diff(tacsat[,"SI_FT"]),0)
  tacsat[which(startTrip>0),"SI_FT"] <-  tacsat[which(startTrip>0)+1,"SI_FT"] # tricky here 
  tacsat <- tacsat[which(inHarb==0 |  startTrip>0),] 
  
  # assign a state to each ping (start guesses only)
  tacsat$SI_STATE <- 2 # init (1: fishing; 2: steaming)
  tacsat$SI_STATE [(tacsat$SI_SP>4 & tacsat$SI_SP<8)] <-1 # fake speed rule for fishing state
                     
  
  # reduce the size of the eflalo data by merging species (e.g. <1 millions euros)
  # (assuming that the other species is coded MZZ)
  eflalo <- poolEflaloSpecies (eflalo2, threshold=1e6, code="MZZ") 
  
  # debug
  eflalo2 <- eflalo2[!eflalo2$VE_REF=="NA" &!is.na(eflalo2$VE_REF),]
  if(all(is.na(eflalo2$VE_FLT))) eflalo2$VE_FLT <- "fleet1"
    if(!match('LE_MET_level6',colnames(eflalo2))>0) eflalo2$LE_MET_level6 <- eflalo2$LE_MET
 
  # TEST FOR A GIVEN SET OF VESSELS
  # (if do.wp3 is at true then do also the automatic detection of fishing states
  # that will overwrite the existing SI_STATE)
  mergeEflalo2Pings (logbooks=eflalo2, tacsat=tacsat, a.vesselid=c("35", "1518"),
                                 general=list(output.path=file.path("C:","output"),
                                    visual.check=TRUE,
                                        do.wp3=TRUE, speed="segment"))
  # ...OR APPLY FOR ALL VESSELS IN eflalo2
  mergeEflalo2Pings (logbooks=eflalo2, tacsat=tacsat,
                                   general=list(output.path=file.path("C:","output"),
                                      visual.check=TRUE,
                                         do.wp3=FALSE, speed="segment"))
  gc(reset=TRUE)

  # load the merged output table for one vessel
  load(file.path("C:","output","merged_35_2009.RData"))
  
  # check the conservation of landings
  sum(tapply(an(merged$LE_KG_PLE), merged$flag, sum, na.rm=TRUE))
  sum(eflalo2[eflalo2$VE_REF=="35","LE_KG_PLE"], na.rm=TRUE)

  
  # ...or bind all vessels (keeping only some given species here)
  bindAllMergedTables (vessels=c("35", "1518"), species.to.keep=c("PLE","COD"), 
                      folder = file.path("C:","output"), all.in.one.table=TRUE)
 
   # ...and load the merged output table for all vessels
  load(file.path("C:","output","all_merged__2009.RData"))
             
  # map landing of cod from all studied vessels
  df1<- all.merged[, c("SI_LATI","SI_LONG","LE_KG_COD")]
  df1$SI_LONG <- anf(df1$SI_LONG)
  df1$SI_LATI <- anf(df1$SI_LATI)
  df1 <-   df1[ !is.na(df1$SI_LATI),]
  df1 <-   df1[ !is.na(df1$SI_LONG),]
  vmsGridCreate(df1,nameLon="SI_LONG",nameLat="SI_LATI", nameVarToSum = "LE_KG_COD",
                                 cellsizeX =0.05,cellsizeY =0.05,  legendtitle = "landings (kg)")

  # remove steaming points before gridding!
  df2<-df1[-which(is.na(df1$LE_KG_COD)),]
  vmsGridCreate(df2,nameLon="SI_LONG",nameLat="SI_LATI", nameVarToSum = "LE_KG_COD",
                                cellsizeX =0.05,cellsizeY =0.05,  legendtitle = "landings (kg)", 
                                 breaks0=c(1,2,4,8,16,32,64,100000))



  # CONVERT TO FISHFRAME FORMAT (might take some time running)
  # (by default, this will keep all the species in the output table)
  tmp <- bindAllMergedTables (vessels= unique(tacsat$VE_REF), species.to.keep=character(), 
                      folder = file.path("C:","output"), all.in.one.table=FALSE)
  
  ff  <- pings2Fishframe (general=list(output.path=file.path("C:","output"),
                                                   a.year=2009, a.country="NLD") )

 
 
  
  # TO DO....
  # Use the interpolation routine to improve the location of the effort
  #all.merged$SI_SP <- as.numeric(as.character( all.merged$SI_SP))
  #all.merged$SI_HE <- as.numeric(as.character( all.merged$SI_HE))
  #all.merged$SI_LONG <-as.numeric(as.character(all.merged$SI_LONG))
  #all.merged$SI_LATI <-as.numeric(as.character(all.merged$SI_LATI))
  #interpolations      <- interpolateTacsat( all.merged [,c("VE_REF","SI_LATI","SI_LONG","SI_DATE","SI_TIME","SI_SP","SI_HE")]
  #                            ,interval=120             
  #                            ,margin=12               
  #                            ,res=100                
  #                            ,method="cHs"           
  #                            ,params=list(fm=0.5,distscale=20,sigline=0.2,st=c(2,6)) 
  #                            ,headingAdjustment=0
  #                            )
  #interpolationsED <- equalDistance(interpolations,res=10)
  # make sure that the 'res' statement in the interpolateTacsat is significantly bigger 
  # than the 'res' statement in the equalDistance function.
   
  # then map again...
  #vmsGridCreate(interpolationsED,nameLon="SI_LONG",nameLat="SI_LATI", 
  #          cellsizeX =0.05, cellsizeY =0.05, legendtitle = "landings (kg)")

  
               
  #}
 
} # end main

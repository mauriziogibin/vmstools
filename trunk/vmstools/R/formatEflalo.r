formatEflalo <- function(x){
  x$VE_REF        <- ac(x$VE_REF)
  x$VE_FLT        <- ac(x$VE_FLT)
  x$VE_COU        <- ac(x$VE_COU)
  x$VE_LEN        <- an(ac(x$VE_LEN))
  x$VE_KW         <- an(ac(x$VE_KW))
  if("VE_TON" %in% colnames(x))       x$VE_TON        <- an(ac(x$VE_TON))
  x$FT_REF        <- ac(x$FT_REF)
  x$FT_DCOU       <- ac(x$FT_DCOU)
  x$FT_DHAR       <- ac(x$FT_DHAR)
  x$FT_DDAT       <- ac(x$FT_DDAT)
  x$FT_DTIME      <- ac(x$FT_DTIME)
  x$FT_LCOU       <- ac(x$FT_LCOU)
  x$FT_LHAR       <- ac(x$FT_LHAR)
  x$FT_LDAT       <- ac(x$FT_LDAT)
  x$FT_LTIME      <- ac(x$FT_LTIME)
  x$LE_ID         <- ac(x$LE_ID)
  x$LE_CDAT       <- ac(x$LE_CDAT)
  if("LE_STIME" %in% colnames(x)) x$LE_STIME      <- ac(x$LE_STIME)
  if("LE_ETIME" %in% colnames(x)) x$LE_ETIME      <- ac(x$LE_ETIME)
  if("LE_SLAT"  %in% colnames(x)) x$LE_SLAT       <- an(ac(x$LE_SLAT))
  if("LE_SLON"  %in% colnames(x)) x$LE_SLON       <- an(ac(x$LE_SLON))
  if("LE_ELAT"  %in% colnames(x)) x$LE_ELAT       <- an(ac(x$LE_ELAT))
  if("LE_ELON"  %in% colnames(x)) x$LE_ELON       <- an(ac(x$LE_ELON))
  x$LE_GEAR       <- ac(x$LE_GEAR)
  x$LE_MSZ        <- an(ac(x$LE_MSZ))
  x$LE_RECT       <- ac(x$LE_RECT)
  X$LE_DIV        <- ac(x$LE_DIV)
  if(length(grep("LE_MET",colnames(x)))>0) x[,grep("LE_MET",colnames(x))] <- ac(x[,grep("LE_MET",colnames(x))])
  for(i in c(grep("_KG_",colnames(x)),grep("_EURO_",colnames(x)))) x[,i] <- an(ac(x[,i]))
  return(x)
}





## `utils_fastqc.R' contains utility functions to analyze outputs from the
## FastQC program (http://www.bioinformatics.babraham.ac.uk/projects/fastqc/)
## Copyright (C) 2014-2015 Institut National de la Recherche Agronomique (INRA)
## License: GPL-3+
## Persons: Timothée Flutre [cre,aut], Nicolas Rode [ctb]
## Version: see below
## Download: https://github.com/timflutre/quantgen
##
## This program is free software: you can redistribute it and/or modify
## it under the terms of the GNU General Public License as published by
## the Free Software Foundation, either version 3 of the License, or
## (at your option) any later version.
##
## This program is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
## GNU General Public License for more details.
##
## You should have received a copy of the GNU General Public License
## along with this program. If not, see <http://www.gnu.org/licenses/>.

utils_fastqc.version <- "2.0.5" # http://semver.org/

##' Reads a "fastqc_data.txt" file generated by FastQC.
##'
##' Heavily inspired from readFastQC() in the Repitools package.
##' @param file the name of the file which the data are to be read from
##' @return list
##' @author Timothée Flutre [cre,aut]
read.fastqc.txt <- function(file){
  stopifnot(file.exists(file),
            grepl(pattern="##FastQC", x=readLines(file, n=1)))
  temp <- readLines(file)
  temp <- gsub("#", "", temp)
  temp <- temp[!grepl(">>END_MODULE", temp)]
  temp <- split(temp, cumsum(grepl("^>>", temp)))[-1]
  names(temp) <- sapply(temp, function(x) {
    gsub("^>>", "", gsub("\t.*", "", gsub(" ", "_", x[1])))
  })
  temp <- lapply(temp, function(x) {
    if(length(x)==1)
      return(data.frame())
    x <- strsplit(x[-1], split="\t")
    tab <- as.data.frame(do.call(rbind, x[-1]), stringsAsFactors=FALSE)
    for(i in 1:ncol(tab))
      if(!any(is.na(suppressWarnings(as.numeric(tab[,i])))))
        tab[,i] <- as.numeric(tab[,i])
    colnames(tab) <- x[[1]]
    tab
  })
  return(temp)
}

##' Loads several zip archives generated by FastQC.
##'
##' Zip archives are decompressed in a temporary directory which is removed afterwards.
##' @param path character vector of the path to the directory containing the zip archives (will be followed by "*_fastqc.zip")
##' @param glob character vector with wildcard(s) to find zip archives
##' @param verbose verbosity level
##' @return list of lists (one per zip archive)
##' @author Timothée Flutre [cre,aut], Nicolas Rode [ctb]
read.fastq.zips <- function(path=".", glob="*_fastqc.zip", verbose=0){
  zip.archives <- Sys.glob(paste(path, glob, sep="/"))
  if(length(zip.archives) == 0)
    stop("not a single zip archive was found", call.=FALSE)
  message(paste("nb of zip archives detected:", length(zip.archives)))

  all.qc <- lapply(zip.archives, function(zip.archive){
    qc <- NULL

    zipdir <- tempfile()
    dir.create(zipdir)

    if(verbose > 0)
      message(paste0("try to unzip ", zip.archive))
    retval <- tryCatch(
        {
          unzip(zip.archive, exdir=zipdir)
        },
        warning = function(w){
          message(paste(basename(zip.archive), "could no be unzipped."))
          message("Original warning message:")
          message(paste0(w, ""))
        },
        error = function(e){
          message(paste(basename(zip.archive), "could no be unzipped."))
          message("Original error message:")
          message(paste0(e, ""))
        })

    if(! is.null(retval)){
      if(verbose > 0)
        message(paste0("try to read fastqc_data.txt"))
      tryCatch(
          {
            f.base <- sub(".zip", "", basename(zip.archive))
            qc <- read.fastqc.txt(paste0(zipdir, "/", f.base, "/fastqc_data.txt"))
          },
          warning = function(w){
            qc <- list(warn="warning")
            message(paste0(sub(".zip", "", basename(zip.archive)),
                           ".txt could no be found."))
            message("Original warning message:")
            message(paste0(w, ""))
          },
          error = function(e){
            qc <- list(err="error")
            message(paste0(sub(".zip", "", basename(zip.archive)),
                           ".txt could no be found."))
            message("Original error message:")
            message(paste0(e, 33))
          })
    }

    unlink(zipdir)
    return(qc)
	})

  names(all.qc) <- sapply(zip.archives, function(zip.archive){
    sub("_fastqc.zip", "", basename(zip.archive))
  })

  return(all.qc[! sapply(all.qc, is.null)])
}

##' Returns the number of sequences per entry in a set of zip archives generated by FastQC.
##'
##' To be used after read.fastq.zips().
##' @param all.qc return value from read.fastq.zips()
##' @return numeric vector
##' @author Timothée Flutre [cre,aut]
nreads.fastqc <- function(all.qc){
  stopifnot(is.list(all.qc), ! is.null(names(all.qc)))
  sapply(all.qc, function(qc){
    as.numeric(qc[["Basic_Statistics"]]$Value[qc[["Basic_Statistics"]]$Measure
                                              == "Total Sequences"])
  })
}

##' Creates a bar plot with the number of sequences per entry in a set of zip archives generated by FastQC.
##'
##' To be used after nreads.fastqc().
##' @param x numeric vector with the number of sequences per entry
##' @param main an overall title for the plot
##' @param cex numeric character expansion factor for x-axis labels
##' @return None
##' @author Timothée Flutre [cre,aut]
barplot.nreads.fastqc <- function(x, main="", cex=1){
  stopifnot(is.vector(x), is.numeric(x), ! is.null(names(x)))
  par(mar=c(10, 7, 4, 1))
  bp <- barplot(sort(x), xaxt="n", xlab="", ylab="Number of sequences",
                main=main)
  axis(1, at=bp, labels=FALSE)
  text(bp, par("usr")[3], srt=45, adj=1.1, labels=names(sort(x)),
       xpd=TRUE, cex=cex)
}

##' Returns the number, or percentage, of sequences per quality score per entry in a set of zip archives generated by FastQC.
##'
##' To be used after read.fastq.zips().
##' @param all.qc return value from read.fastq.zips()
##' @param perc return percentage of sequences if TRUE, number of sequences otherwise
##' @param nreads return value from nreads.fastqc(), required if perc=TRUE
##' @return numeric matrix with entries in rows and number (percentage) of sequences per quality in columns
##' @author Timothée Flutre [cre,aut]
quals.fastqc <- function(all.qc, perc=FALSE, nreads=NULL){
  stopifnot(is.list(all.qc), ! is.null(names(all.qc)),
            ifelse(perc, ! is.null(nreads), TRUE))
  N <- length(all.qc)
  qual <- matrix(NA, nrow=N, ncol=50,
                 dimnames=list(names(all.qc), paste0("Q=", 1:50)))
  for(i in 1:N)
    qual[i, all.qc[[i]][["Per_sequence_quality_scores"]][,"Quality"]] <-
      all.qc[[i]][["Per_sequence_quality_scores"]][,"Count"]
  if(perc)
    for(i in 1:nrow(qual))
      qual[i,] <- (qual[i,] / nreads[i]) * 100
  return(qual)
}

##' Plot the number, or percentage, of sequences per quality score with one curve per dataset.
##'
##' To be used after quals.fastqc().
##' @param qual return value from quals.fastqc()
##' @param perc value of perc used when qual was generated by quals.fastqc()
##' @param ylim left and right limits of the y-axis (will be min and max of qual by default)
##' @param max.dataset.per.plot max number of datasets on the same plot
##' @param main an overall title for the plot
##' @param legend.x x co-ordinate to position the legend (no legend if NULL)
##' @param legend.y y co-ordinate to position the legend
##' @param legend.cex numeric character expansion factor for legend labels
##' @return None
##' @author Timothée Flutre [cre,aut], Nicolas Rode [ctb]
plot.nbseq.qual <- function(qual,
                            perc=FALSE,
                            ylim=NULL,
                            max.dataset.per.plot=25,
                            main="Quality control",
                            legend.x="topleft",
                            legend.y=NULL,
                            legend.cex=1){
  stopifnot(is.matrix(qual),
            ! is.null(rownames(qual)))

  lowest.qual <- NA
  for(j in 1:ncol(qual)){
    if(any(! is.na(qual[,j]))){
      lowest.qual <- j
      break
    }
  }

  highest.qual <- NA
  for(j in ncol(qual):1){
    if(any(! is.na(qual[,j]))){
      highest.qual <- j
      break
    }
  }

  lowest.count <- min(qual[,lowest.qual])
  highest.count <- max(qual[,lowest.qual])
  for(j in lowest.qual:highest.qual){
    lowest.count <- min(lowest.count, qual[,j], na.rm=TRUE)
    highest.count <- max(highest.count, qual[,j], na.rm=TRUE)
  }

  ylab <- "Number of sequences"
  if(perc){
    ylab <- "Percentage of sequences"
  }
  if(is.null(ylim))
    ylim <- c(lowest.count, highest.count)

  dividend <- nrow(qual) %/% max.dataset.per.plot
  if(nrow(qual) > max.dataset.per.plot){
    for(k in 1:dividend){
      plot(x=0, y=0,
           xlim=c(lowest.qual, highest.qual), ylim=ylim,
           xlab="Phred quality", ylab=ylab,
           main=main,
           type="n", bty="n")
      for(i in ((k-1)*max.dataset.per.plot+1):(k*max.dataset.per.plot)){
        l <- i - (k-1) * max.dataset.per.plot
        idx <- which(! is.na(qual[i,]))
        points(x=idx, y=qual[i,idx], col=l, pch=l, type="b")
      }
      axis(side=4)
      if(! is.null(legend.x))
        legend(x=legend.x, y=legend.y,
               legend=rownames(qual)[((k-1)*max.dataset.per.plot+1):(k*max.dataset.per.plot)],
               cex=legend.cex, col=1:max.dataset.per.plot, pch=1:max.dataset.per.plot, bty="n")
    }
  }
  if((dividend*max.dataset.per.plot) < nrow(qual)){
    plot(x=0, y=0,
         xlim=c(lowest.qual, highest.qual), ylim=ylim,
         xlab="Phred quality", ylab=ylab,
         main=main,
         type="n", bty="n")
    for(i in (dividend*max.dataset.per.plot+1):nrow(qual)){
      l <- i %% max.dataset.per.plot
      idx <- which(! is.na(qual[i,]))
      points(x=idx, y=qual[i,idx], col=l, pch=l, type="b")
    }
    axis(side=4)
    if(! is.null(legend.x))
      legend(x=legend.x, y=legend.y,
             legend=rownames(qual)[(dividend*max.dataset.per.plot+1):nrow(qual)],
             cex=legend.cex, col=1:l, pch=1:l, bty="n")
  }
}


##' Returns the adapter content along the sequences per entry in a set of zip archives generated by FastQC.
##'
##' To be used after read.fastq.zips().
##' @param all.qc return value from read.fastq.zips()
##' @param adp name of the adapter to plot (default="Illumina Universal Adapter")
##' @return numeric matrix with entries in rows and positions along sequences in columns
##' @author Timothée Flutre [cre,aut], Nicolas Rode [ctb]
adp.contents.fastqc <- function(all.qc, adp="Illumina Universal Adapter"){
  stopifnot(is.list(all.qc), ! is.null(names(all.qc)))
  N <- length(all.qc)
  L <- NULL
  for(i in 1:N)
    L <- c(L, length(all.qc[[i]]$Adapter_Content[["Position"]]))
  max <- which(L == max(L))[1]
  positions <- all.qc[[max]]$Adapter_Content[["Position"]]
  adp.content <- matrix(NA, nrow=N, ncol=length(positions),
                        dimnames=list(names(all.qc), positions))
  for(i in 1:N){
    stopifnot(adp %in% names(all.qc[[i]]$Adapter_Content))
    dif <- L[max] - L[i]
    if(dif == 0){
      adp.content[i,] <- all.qc[[i]]$Adapter_Content[[adp]]
    } else
      adp.content[i,] <- c(all.qc[[i]]$Adapter_Content[[adp]], rep(0,dif))
  }
  return(adp.content)
}

##' Plot the content in adapters (%) along the sequences per entry in a set of zip archives generated by FastQC.
##'
##' To be used after adp.contents.fastqc().
##' @param adp.content return value from adp.contents.fastqc()
##' @param max.dataset.per.plot max number of datasets on the same plot
##' @param lowest.adp lowest percentage of adapter content for the y-axis
##' @param highest.adp highest percentage of adapter content for the y-axis
##' @param main an overall title for the plot
##' @param legend.x x co-ordinate to position the legend (no legend if NULL)
##' @param legend.y y co-ordinate to position the legend
##' @param legend.cex numeric character expansion factor for legend labels
##' @return None
##' @author Timothée Flutre [cre,aut], Nicolas Rode [ctb]
plot.adp.content <- function(adp.content,
                             max.dataset.per.plot=25,
                             lowest.adp=NULL,
                             highest.adp=NULL,
                             main="Quality control",
                             legend.x="topleft",
                             legend.y=NULL,
                             legend.cex=1){
  stopifnot(is.matrix(adp.content),
            ! is.null(rownames(adp.content)),
            ! is.null(colnames(adp.content)))

  positions <- sapply(strsplit(colnames(adp.content), "-"),
                      function(x){as.numeric(x[1])})

  if(is.null(lowest.adp))
    lowest.adp <- min(c(adp.content))
  if(is.null(highest.adp))
    highest.adp <- max(c(adp.content))

  dividend <- nrow(adp.content) %/% max.dataset.per.plot
  if(nrow(adp.content) > max.dataset.per.plot){
    for(k in 1:dividend){
      plot(x=0, y=0,
           xlim=c(positions[1], positions[length(positions)]),
           ylim=c(lowest.adp, highest.adp),
           xlab="Positions (bp)",
           ylab="Adapter content (%)",
           main=main,
           type="n")
      for(i in ((k-1)*max.dataset.per.plot+1):(k*max.dataset.per.plot)){
        l <- i - (k-1) * max.dataset.per.plot
        points(x=positions, y=adp.content[i,], col=l, pch=l, type="b")
      }
      axis(side=4)
      if(! is.null(legend.x))
        legend(x=legend.x, y=legend.y,
               legend=rownames(adp.content)[((k-1)*max.dataset.per.plot+1):(k*max.dataset.per.plot)],
               col=1:max.dataset.per.plot, pch=1:max.dataset.per.plot, bty="n", cex=legend.cex)
    }
  }
  if((dividend*max.dataset.per.plot) < nrow(adp.content)){
    plot(x=0, y=0,
         xlim=c(positions[1], positions[length(positions)]),
         ylim=c(lowest.adp, highest.adp),
         xlab="Positions (bp)",
         ylab="Adapter content (%)",
         main=main,
         type="n")
    for(i in (dividend*max.dataset.per.plot+1):nrow(adp.content)){
      l <- i %% max.dataset.per.plot
      points(x=positions, y=adp.content[i,], col=l, pch=l, type="b")
    }
    axis(side=4)
    if(! is.null(legend.x))
      legend(x=legend.x, y=legend.y,
             legend=rownames(adp.content)[(dividend*max.dataset.per.plot+1):nrow(adp.content)],
             col=1:l, pch=1:l, bty="n", cex=legend.cex)
  }
}

##' Returns the sequence length distribution per entry in a set of zip archives generated by FastQC.
##'
##' To be used after read.fastq.zips().
##' @param all.qc return value from read.fastq.zips()
##' @return numeric matrix with entries in rows and positions along sequences in columns
##' @author Timothée Flutre [cre,aut], Nicolas Rode [ctb]
seq.lengths.fastqc <- function(all.qc){
  stopifnot(is.list(all.qc), ! is.null(names(all.qc)))
  N <- length(all.qc)
  positions <- lapply(1:N, function(i){
    as.character(all.qc[[i]]$Sequence_Length_Distribution[["Length"]])
  })
  positions <- unique(sort(sapply(
      strsplit(do.call(c, positions), "-"), function(x){
        as.numeric(x[1])
      })))
  seq.lengths <- matrix(0, nrow=N, ncol=length(positions),
                        dimnames=list(names(all.qc), positions))
  for(i in 1:N){
    tmp <- all.qc[[i]]$Sequence_Length_Distribution
    if (length(grep("-",tmp$Length)) != 0)
      tmp$Length <- sapply(strsplit(tmp$Length, "-"), function(x){x[1]})
    seq.lengths[i,as.character(tmp$Length)] <- tmp$Count
  }
  return(seq.lengths)
}

##' Plot the distribution of sequence lengths per entry in a set of zip archives generated by FastQC.
##'
##' To be used after seq.lengths.fastqc().
##' @param seq.length matrix with datasets in rows and number of sequences per length in columns
##' @param max.dataset.per.plot max number of datasets on the same plot
##' @param lowest.len lowest sequence length for the y-axis
##' @param highest.len highest sequence length for the y-axis
##' @param main an overall title for the plot
##' @param ylab label for the y-axis
##' @param legend.x x co-ordinate to position the legend (no legend if NULL)
##' @param legend.y y co-ordinate to position the legend
##' @param legend.cex numeric character expansion factor for legend labels
##' @return None
##' @author Timothée Flutre [cre,aut], Nicolas Rode [ctb]
plot.seq.length <- function(seq.length,
                            max.dataset.per.plot=25,
                            lowest.len=NULL,
                            highest.len=NULL,
                            main="Quality control",
                            ylab="Number of sequences",
                            legend.x="topleft",
                            legend.y=NULL,
                            legend.cex=1){
  stopifnot(is.matrix(seq.length),
            ! is.null(rownames(seq.length)),
            ! is.null(colnames(seq.length)))

  lengths <- sapply(strsplit(colnames(seq.length), "-"),
                    function(x){as.numeric(x[1])})

  if(is.null(lowest.len)){
    lowest.len <- min(c(seq.length))
    if(is.infinite(lowest.len))
      stop("did you give log10(seq.length)? maybe use also lowest.len=0")
  }
  if(is.null(highest.len))
    highest.len <- max(c(seq.length))

  dividend <- nrow(seq.length) %/% max.dataset.per.plot
  if(nrow(seq.length) > max.dataset.per.plot){
    for(k in 1:dividend){
      plot(x=0, y=0,
           xlim=c(lengths[1], lengths[length(lengths)]),
           ylim=c(lowest.len, highest.len),
           xlab="Sequence lengths (bp)",
           ylab=ylab,
           main=main,
           type="n")
      for(i in ((k-1)*max.dataset.per.plot+1):(k*max.dataset.per.plot)){
        l <- i - (k-1) * max.dataset.per.plot
        points(x=lengths, y=seq.length[i,], col=l, pch=l, type="b")
      }
      axis(side=4)
      if(! is.null(legend.x))
        legend(x=legend.x, y=legend.y,
               legend=rownames(seq.length)[((k-1)*max.dataset.per.plot+1):(k*max.dataset.per.plot)],
               col=1:max.dataset.per.plot, pch=1:max.dataset.per.plot, bty="n", cex=legend.cex)
    }
  }
  if((dividend*max.dataset.per.plot) < nrow(seq.length)){
    plot(x=0, y=0,
         xlim=c(lengths[1], lengths[length(lengths)]),
         ylim=c(lowest.len, highest.len),
         xlab="Sequence lengths (bp)",
         ylab=ylab,
         main=main,
         type="n")
    for(i in (dividend*max.dataset.per.plot+1):nrow(seq.length)){
      l <- i %% max.dataset.per.plot
      points(x=lengths, y=seq.length[i,], col=l, pch=l, type="b")
    }
    axis(side=4)
    if(! is.null(legend.x))
      legend(x=legend.x, y=legend.y,
             legend=rownames(seq.length)[(dividend*max.dataset.per.plot+1):nrow(seq.length)],
             col=1:l, pch=1:l, bty="n", cex=legend.cex)
  }
}


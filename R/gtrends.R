#' Google Trends Query
#' 
#' The \code{gtrends} default method performs a Google Trends query for the 
#' \sQuote{query} argument and session \sQuote{session}. Optional arguments for 
#' geolocation and category can also be supplied.
#' 
#' @param keyword A character vector with the actual Google Trends query 
#'   keywords. Multiple keywords are possible using \code{gtrends(c("NHL", 
#'   "NBA", "MLB", "MLS"))}.
#'   
#' @param geo A character vector denoting geographic regions for the query, 
#'   default to \dQuote{all} for global queries. Multiple regions are possible 
#'   using \code{gtrends("NHL", c("CA", "US"))}.
#'   
#' @param time A string specifying the time span of the query. Possible values
#'   are:
#'   
#'   \describe{ \item{"now 1-H"}{Last hour} \item{"now 4-H"}{Last four hours} 
#'   \item{"now 1-d"}{Last day} \item{"now 7-d"}{Last seven days} \item{"today
#'   1-m"}{Past 30 days} \item{"today 3-m"}{Past 90 days} \item{"today
#'   12-m"}{Past 12 months} \item{"today+5-y"}{Last five years (default)} 
#'   \item{"all"}{Since the beginning of Google Trends (2004)} \item{"Y-m-d
#'   Y-m-d"}{Time span between two dates (ex.: "2010-01-01 2010-04-03")} }
#'   
#' @param category A character denoting the category, defaults to \dQuote{0}.
#'   
#' @param gprop A character string defining the Google product for which the 
#'   trend query if preformed. Valid options are:
#'   
#'   \itemize{ \item "web" (default) \item "news" \item "images" \item "froogle"
#'   \item "youtube" }
#'   
#' @param hl A string specifying the ISO language code (ex.: \dQuote{en-US} or 
#'   \dQuote{fr}). Default is \dQuote{en-US}. Note that this is only influencing
#'   the data returned by related topics.
#'   
#' @section Categories: The package includes a complete list of categories that 
#'   can be used to narrow requests. These can be accessed using 
#'   \code{data("categories")}.
#'   
#' @section Related topics: Note that *related topics* are not retrieved when
#'   more than one keyword is provided due to Google restriction.
#'   
#' @importFrom stats na.omit reshape
#' @importFrom utils URLencode read.csv
#'   
#' @return An object of class \sQuote{gtrends} (basically a list of data
#'   frames).
#'   
#' @examples
#' 
#' head(gtrends("NHL")$interest_over_time)
#' head(gtrends("NHL")$related_topics)
#' head(gtrends("NHL")$related_queries)
#' 
#' head(gtrends(c("NHL", "NFL"))$interest_over_time)
#' 
#' head(gtrends(c("NHL", "NFL"), geo = c("CA", "US"))$interest_over_time)
#' 
#' ## Sport category (20)
#' data(categories)
#' categories[grepl("^Sport", categories$name), ]
#' head(gtrends(c("NHL", "NFL"), geo = c("CA", "US"), category = 20))
#' 
#' ## Playing with time format
#' 
#' head(gtrends(c("NHL", "NFL"), time = "now 1-H")) # last hour
#' head(gtrends(c("NHL", "NFL"), time = "now 4-H")) # last four hours
#' head(gtrends(c("NHL", "NFL"), time = "now 1-d")) # last day
#' head(gtrends(c("NHL", "NFL"), time = "today 1-m")) # last 30 days
#' head(gtrends(c("NHL", "NFL"), time = "today 3-m")) # last 90 days
#' head(gtrends(c("NHL", "NFL"), time = "today 12-m")) # last 12 months
#' head(gtrends(c("NHL", "NFL"), time = "today+5-y")) # last five years (default)
#' head(gtrends(c("NHL", "NFL"), time = "all")) # since 2004
#' 
#' ## Custom date format
#' 
#' head(gtrends(c("NHL", "NFL"), time = "2010-01-01 2010-04-03")) 
#' 
#' ## Search from various Google's services
#' 
#' head(gtrends(c("NHL", "NFL"), gprop = "news")$interest_over_time)
#' head(gtrends(c("NHL", "NFL"), gprop = "youtube")$interest_over_time)
#' 
#' ## Language settings
#' 
#' head(gtrends("NHL", hl = "en")$related_topics)
#' head(gtrends("NHL", hl = "fr")$related_topics)
#' 
#' @export
gtrends <- function(
  keyword, 
  geo = "", 
  time = "today+5-y", 
  gprop = c("web", "news", "images", "froogle", "youtube"), 
  category = 0,
  hl = "en-US") {
  
  stopifnot(
    # One  vector should be a multiple of the other
    (length(keyword) %% length(geo) == 0) || (length(geo) %% length(keyword) == 0),
    is.vector(keyword),
    length(keyword) <= 5,
    length(geo) <= 5,
    length(time) == 1,
    length(hl) == 1,
    is.character(hl),
    hl %in% language_codes$code
  )

  
  ## Check if valide geo
  if (geo != "" &&
      !all(geo %in% countries[, "country_code"]) &&
      !all(geo %in% countries[, "sub_code"])) {
    stop("Country code not valid. Please use 'data(countries)' to retreive valid codes.",
         call. = FALSE)
  }
  
  ## Check if valide category
  if (!all(category %in% categories[, "id"]))  {
    stop("Category code not valid. Please use 'data(categories)' to retreive valid codes.",
         call. = FALSE)
  }
  
  ## Check if time format is ok
  if (!check_time(time)) {
    stop("Can not parse the supplied time format.", call. = FALSE)
  }
  
  # time <- "today+5-y"
  # time <- "2017-02-09 2017-02-18"
  # time <- "now 7-d"
  # time <- "all_2006"
  # time <- "all"
  # time <- "now 4-H"
  # geo <- c("CA", "FR", "US")
  # geo <- c("CA", "DK", "FR", "US", "CA")
  # geo <- "US"
  
  gprop <- match.arg(gprop, several.ok = FALSE)
  gprop <- ifelse(gprop == "web", "", gprop)
  
  # ****************************************************************************
  # Request a token from Google
  # ****************************************************************************
  
  comparison_item <- data.frame(keyword, geo, time, stringsAsFactors = FALSE)
  
  widget <- get_widget(comparison_item, category, gprop)
  
  # ****************************************************************************
  # Now that we have tokens, we can process the queries
  # ****************************************************************************
  
  interest_over_time <- interest_over_time(widget, comparison_item)
  interest_by_region <- interest_by_region(widget, comparison_item)
  related_topics <- related_topics(widget, comparison_item, hl)
  related_queries <- related_queries(widget, comparison_item)
    
  res <- list(
    interest_over_time = interest_over_time, 
    interest_by_region = interest_by_region$region,
    interest_by_dma = interest_by_region$dma,
    interest_by_city = interest_by_region$city,
    related_topics = related_topics, 
    related_queries = related_queries
  )
  
  class(res) <- c("gtrends", "list")
 
  return(res)
  
}

#' Plot Google Trends interest over time
#' 
#' @param x A \code{\link{gtrends}} object.
#' @param ... Additional parameters passed on in method dispatch. Currently not
#'   used.
#'   
#' @import ggplot2
#'   
#' @return A ggplot2 object is returned silently.
#' @export
#' 
#' @examples
#' res <- gtrends("nhl", geo = c("CA", "US"))
#' plot(res)
plot.gtrends <- function(x, ...) {

  df <- x$interest_over_time
  
  df$legend <-  paste(df$keyword, " (", df$geo, ")", sep = "")
  
  p <- ggplot(df, aes_string(x = "date", y = "hits", color = "legend")) +
    geom_line() +
    xlab("Date") +
    ylab("Search hits") +
    ggtitle("Interest over time") +
    theme_bw() +
    theme(legend.title = element_blank()) 
  
  print(p)
  invisible(p)
   
}
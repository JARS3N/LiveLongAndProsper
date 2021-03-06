related_lots_server <- function() {
    library(shiny)
    library(dplyr)
    db <- adminKraken::con_dplyr()
    shinyServer(function(input, output, session) {
        observeEvent(input$search, {
            mfltbl <- get_related_tbl(input$Lot, input$ltype,db)
            
            output$mftable <-
                DT::renderDataTable({
                    mfltbl
                }, options = list(dom = 'tp'))
            
        })
    })
}

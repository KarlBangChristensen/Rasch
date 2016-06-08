library(shiny)
library(shiny)
write.csv(data.frame(a = 1:10, b = letters[1:10]), 'test.csv')
runApp(list(ui = fluidPage(
  titlePanel("Uploading Files"),
  sidebarLayout(
    sidebarPanel(
      fileInput('file1', 'Choose CSV File',
                accept=c('text/csv',
                         'text/comma-separated-values,text/plain',
                         '.csv'))
    ),
    mainPanel(
      tableOutput('contents')
    )
  )
)
, server = function(input, output, session){
  myData <- reactive({
    inFile <- input$file1
    if (is.null(inFile)) return(NULL)
    data <- read.csv(inFile$datapath, header = TRUE)
    data
  })
  output$contents <- renderTable({
    myData()
  })

}
)
)

shinyUI(pageWithSidebar(
  
  # Application title
  headerPanel("Least squares example"),
  
  sidebarPanel(
    sliderInput("alpha", 
                "Intercept", 
                value = 1,
                min = -1, 
                max = 3,
                step = 0.05),
    
    sliderInput("beta", 
                "Slope", 
                value = 1,
                min = -1, 
                max = 3,
                step = 0.05),
    
    br(),
  
    radioButtons("outputtype", "Output type:",
                 list("Points" = "points",
                      "Residuals" = "residuals",
                      "Squared residuals" = "sqresiduals")),
    
    checkboxInput(inputId = "sse",
                  label = strong("Show sum of squared residuals"),
                  value = FALSE)
  ),
  
  mainPanel(
      plotOutput(outputId = "main_plot", height="600px", width="800px")
  
))
)

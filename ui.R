library(shiny)

shinyUI(pageWithSidebar(
  
  # Application title
  headerPanel("Rasch model"),

  sidebarPanel(
    
    radioButtons("Modeltype", "Model type:",
                 list("Dichtomous Rasch model" = "RM",
                      "Polytomous Rasch model" = "residuals")),
    
    checkboxInput(inputId = "ICC",
                  label = strong("Plot Item Characteristic Curves"),
                  value = FALSE)
  ),
  
  mainPanel(
      #plotOutput(outputId = "main_plot", height="600px", width="800px")
  
))
)

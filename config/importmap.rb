# Pin npm packages by running ./bin/importmap

pin "application"
pin "turbo_confirm"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"

# Bootstrap is loaded via a regular <script> in the layout (UMD bundle.min.js
# with Popper included). Importmap-pinning Popper as ESM is unreliable because
# it pulls dozens of relative-path sub-modules that aren't resolved by importmap.

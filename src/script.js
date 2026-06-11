const button__nav = document.querySelectorAll(".view-btn");
const views = document.querySelectorAll(".view");
button__nav.forEach((button) => {
  button.addEventListener("click", () => {
    const selectedView = button.dataset.view;
    const targetView = document.querySelector(`#${selectedView}-view`);
    button__nav.forEach((btn) => {
      btn.classList.remove("active");
    });
    views.forEach((view) => {
      view.classList.remove("active-view");
    });
    button.classList.add("active");
    targetView.classList.add("active-view");
    window.scrollTo({
      top: document.querySelector("main").offsetTop,
      behavior: "smooth",
    });
  });
});

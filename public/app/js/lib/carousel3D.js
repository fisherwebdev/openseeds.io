define(function () {


  // modified slightly from: http://desandro.github.com/3dtransforms/docs/carousel.html

  var transformProp = Modernizr.prefixed('transform');

  function Carousel3D ( el ) {
    this.element = el;
    this.rotation = 0;
    this.panelCount = 3;
    this.theta = 120;
  }

  Carousel3D.prototype.modify = function() {
    var panel, angle, i;
    this.panelSize = this.element.offsetWidth;

    // do some trig to figure out how big the carousel
    // is in 3D space
    this.radius = Math.round( ( this.panelSize / 2) / Math.tan( Math.PI / this.panelCount ) );

    for ( i = 0; i < this.panelCount; i++ ) {
      panel = this.element.children[i];
      angle = this.theta * i;

      // rotate panel, then push it out in 3D space
      panel.style[ transformProp ] = 'rotateY(' + angle + 'deg) translateZ(' + this.radius + 'px)';
    }

    // adjust rotation so panels are always flat
    this.rotation = Math.round( this.rotation / this.theta ) * this.theta;

    this.transform();
  };

  Carousel3D.prototype.transform = function() {
    // push the carousel back in 3D space,
    // and rotate it
    this.element.style[ transformProp ] = 'translateZ(-' + this.radius + 'px) rotateY(' + this.rotation + 'deg)';
  };

  Carousel3D.prototype.rotate = function (index) {
    this.rotation = this.theta * index * -1;
    this.transform();
  };

  Carousel3D.prototype.ready = function () {
    setTimeout(function () {  // using a setTimeout here defers the execution enough to allow the rendering to happen first
      document.body.className = 'ready ' + document.body.className;
    }, 0);
  }


  return Carousel3D;
});
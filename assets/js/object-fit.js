$(function() {
    if (('objectFit' in document.documentElement.style) &&
        ('objectPosition' in document.documentElement.style))
        return;
    $('#featured .pennant img').each(function() {
        var src = this.currentSrc || this.src;
        this.style.backgroundImage = 'url("' + src + '")';
        // A bit ugly but srcset might override our src attribute otherwise
        this.removeAttribute('srcset');
        this.src = 'data:image/svg+xml,%3Csvg xmlns=\'http://www.w3.org/2000/svg\' width=\'' + this.width + '\' height=\'' + this.height + '\'%3E%3C/svg%3E';
    });
});

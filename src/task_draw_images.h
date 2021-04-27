/*
 * task_draw_images.h
 *
 *  Created on: Apr 25, 2021
 *      Author: icolb
 */

#ifndef TASK_DRAW_IMAGES_H_
#define TASK_DRAW_IMAGES_H_

#include <main.h>

extern TaskHandle_t Task_Draw_Images_Handle;

extern QueueHandle_t draw_queue;

/******************************************************************************
 * Draws images of frog and logs
 ******************************************************************************/
void Task_Draw_Images(void *pvParameters);

void Draw_Game_Base(void);

#endif /* TASK_DRAW_IMAGES_H_ */
